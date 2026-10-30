"""Run on the owner's computer: configure scoped GitHub secrets and Apple signing.
No TinyFish, Apple-account password, or App Store session cookie is used.
Private keys are read locally and sent to GitHub through stdin, never command arguments.
"""
from __future__ import annotations
import argparse,base64,datetime,getpass,json,os,re,secrets,subprocess,sys,time
from pathlib import Path
from cryptography import x509
from cryptography.hazmat.primitives import hashes,serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives.serialization import pkcs12
from cryptography.x509.oid import NameOID
from asc_api import AppleAPI,AppleAPIError

REPO='mistermedico/stepwise-usmle'
SOURCE_BRANCH='cardiofocus/app-store-review'
ROOT=Path(__file__).resolve().parents[1]

class SetupError(RuntimeError):pass

def gh(args,data=None):
    result=subprocess.run(['gh',*args],input=data,capture_output=True)
    if result.returncode:
        # Never include arbitrary command output: provider errors can echo request bodies.
        raise SetupError('GitHub command failed. Verify owner authentication and repository Secrets/Contents/Actions permissions. Command: gh '+args[0])
    return result.stdout

def set_secret(name,value):
    gh(['secret','set',name,'--repo',REPO],value.encode() if isinstance(value,str) else value)
    print('Configured '+name)

def private_write(path,data):
    path.parent.mkdir(parents=True,exist_ok=True)
    if os.name!='nt':path.parent.chmod(0o700)
    # Refuse symlinks when creating/replacing private local signing material.
    flags=os.O_WRONLY|os.O_CREAT|os.O_TRUNC|getattr(os,'O_NOFOLLOW',0)
    descriptor=os.open(str(path),flags,0o600)
    try:
        if os.name!='nt':os.fchmod(descriptor,0o600)
        with os.fdopen(descriptor,'wb',closefd=False) as file:file.write(data)
    finally:os.close(descriptor)

def utc(value):return datetime.datetime.fromisoformat(value.replace('Z','+00:00'))

def signing(api,bundle,state_dir):
    state_file=state_dir/'signing-state.json';key_file=state_dir/'distribution-key.pem'
    state=json.loads(state_file.read_text()) if state_file.exists() else {}
    if state.get('issuerId') and state['issuerId']!=api.issuer_id:raise SetupError('This private signing directory belongs to a different Apple issuer. Select a different --state-directory.')
    certificate=None;key=None
    if state.get('certificateId') and key_file.exists():
        try:certificate=api.request('GET','/v1/certificates/'+state['certificateId'])['data']
        except AppleAPIError as error:
            if error.status!=404:raise
        if certificate:
            cert=x509.load_der_x509_certificate(base64.b64decode(certificate['attributes']['certificateContent']))
            key=serialization.load_pem_private_key(key_file.read_bytes(),password=None)
            if cert.public_key().public_bytes(serialization.Encoding.DER,serialization.PublicFormat.SubjectPublicKeyInfo)!=key.public_key().public_bytes(serialization.Encoding.DER,serialization.PublicFormat.SubjectPublicKeyInfo):
                raise SetupError('Saved certificate does not match the local private key. No existing certificate was revoked.')
            if utc(certificate['attributes']['expirationDate'])<=datetime.datetime.now(datetime.timezone.utc)+datetime.timedelta(days=1):
                raise SetupError('Saved certificate is expiring. Arrange renewal before rerunning; no certificate was automatically revoked.')
    if certificate is None:
        # Save the private key BEFORE issuing the certificate so a failed upload is recoverable.
        # A preexisting saved key is reused if a prior interrupted request issued a matching cert.
        if key_file.exists():key=serialization.load_pem_private_key(key_file.read_bytes(),password=None)
        else:
            key=rsa.generate_private_key(public_exponent=65537,key_size=2048)
            private_write(key_file,key.private_bytes(serialization.Encoding.PEM,serialization.PrivateFormat.PKCS8,serialization.NoEncryption()))
        candidates=api.collection('/v1/certificates',{'filter[certificateType]':'DISTRIBUTION','limit':200})
        expected=key.public_key().public_bytes(serialization.Encoding.DER,serialization.PublicFormat.SubjectPublicKeyInfo)
        for candidate in candidates:
            content=candidate.get('attributes',{}).get('certificateContent')
            if not content:continue
            cert=x509.load_der_x509_certificate(base64.b64decode(content))
            if cert.public_key().public_bytes(serialization.Encoding.DER,serialization.PublicFormat.SubjectPublicKeyInfo)==expected:
                certificate=candidate;break
        if certificate is None:
            subject=x509.Name([x509.NameAttribute(NameOID.COMMON_NAME,'CardioFocus Distribution')])
            csr=x509.CertificateSigningRequestBuilder().subject_name(subject).sign(key,hashes.SHA256()).public_bytes(serialization.Encoding.PEM).decode()
            try:certificate=api.request('POST','/v1/certificates',{'data':{'type':'certificates','attributes':{'certificateType':'DISTRIBUTION','csrContent':csr}}})['data']
            except AppleAPIError as error:
                if error.status in [403,409]:raise SetupError('Apple did not permit a new distribution certificate (permissions or quota). No existing certificates were revoked. Reuse owner-controlled signing material or resolve the Apple account limit.') from None
                raise
        state['certificateId']=certificate['id'];state['issuerId']=api.issuer_id;private_write(state_file,json.dumps(state).encode())
    cert=x509.load_der_x509_certificate(base64.b64decode(certificate['attributes']['certificateContent']))
    teams=cert.subject.get_attributes_for_oid(NameOID.ORGANIZATIONAL_UNIT_NAME)
    if len(teams)!=1:raise SetupError('Could not determine the actual Apple team from its distribution certificate.')
    team=teams[0].value
    profile=None
    if state.get('profileId'):
        try:
            found=api.request('GET','/v1/profiles/'+state['profileId'])['data']
            if found['attributes']['profileState']=='ACTIVE' and utc(found['attributes']['expirationDate'])>datetime.datetime.now(datetime.timezone.utc)+datetime.timedelta(days=1):
                linked_bundle=api.request('GET','/v1/profiles/'+found['id']+'/bundleId')['data']
                linked_certs=api.collection('/v1/profiles/'+found['id']+'/certificates')
                if linked_bundle['id']==bundle['id'] and any(c['id']==certificate['id'] for c in linked_certs):profile=found
        except AppleAPIError as error:
            if error.status!=404:raise
    if profile is None:
        profile=api.request('POST','/v1/profiles',{'data':{'type':'profiles','attributes':{'name':'CardioFocus App Store '+certificate['id'][-8:],'profileType':'IOS_APP_STORE'},'relationships':{'bundleId':{'data':{'type':'bundleIds','id':bundle['id']}},'certificates':{'data':[{'type':'certificates','id':certificate['id']}]}}}})['data']
        state['profileId']=profile['id'];private_write(state_file,json.dumps(state).encode())
    password=secrets.token_urlsafe(32)
    p12=pkcs12.serialize_key_and_certificates(b'CardioFocus Distribution',key,cert,None,serialization.BestAvailableEncryption(password.encode()))
    return team,p12,password,profile['attributes']['profileContent']

def choose_upload_build(api,app_id,marketing_version,requested=None):
    builds=api.collection('/v1/builds',{'filter[app]':app_id,'filter[preReleaseVersion.version]':marketing_version,'filter[preReleaseVersion.platform]':'IOS','limit':200})
    def parts(value):
        if not re.fullmatch(r'[0-9]+(?:\.[0-9]+){0,2}',value):raise SetupError('Existing build format is unexpected; review build numbering manually.')
        numbers=[int(p) for p in value.split('.')];return tuple(numbers+[0]*(3-len(numbers)))
    existing=[parts(b['attributes']['version']) for b in builds]
    if requested:
        candidate=parts(requested)
        if candidate[0]<1 or (existing and candidate<=max(existing)):raise SetupError('Choose a build number newer than the existing Apple builds.')
        return requested
    return str(max((p[0] for p in existing),default=0)+1)


def trigger(branch,message):
    ref=json.loads(gh(['api','repos/'+REPO+'/git/ref/heads/'+SOURCE_BRANCH]))
    head=ref['object']['sha'];commit=json.loads(gh(['api','repos/'+REPO+'/git/commits/'+head]))
    stamp=datetime.datetime.now(datetime.timezone.utc)
    body={'message':message+' '+stamp.isoformat(),'tree':commit['tree']['sha'],'parents':[head]}
    created=json.loads(gh(['api','repos/'+REPO+'/git/commits','--input','-'],json.dumps(body).encode()))
    # A fresh isolated trigger branch avoids force-updating or overwriting existing branches.
    unique=branch+'/'+stamp.strftime('%Y%m%dT%H%M%S%fZ')
    gh(['api','repos/'+REPO+'/git/refs','--input','-'],json.dumps({'ref':'refs/heads/'+unique,'sha':created['sha']}).encode())
    print('Started '+unique+' at '+created['sha'][:12])
    print('Monitor: https://github.com/'+REPO+'/actions')


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--key-file',type=Path,required=True,help='Local Apple .p8 file; never upload it to a public repository')
    parser.add_argument('--key-id');parser.add_argument('--issuer-id');parser.add_argument('--contact-file',type=Path)
    parser.add_argument('--state-directory',type=Path,default=Path.home()/'.cardiofocus-signing')
    group=parser.add_mutually_exclusive_group();group.add_argument('--start-upload',action='store_true');group.add_argument('--submit-review',action='store_true')
    parser.add_argument('--build-number')
    args=parser.parse_args()
    gh(['api','user'])  # Confirm local owner authentication before touching Apple resources.
    key_id=args.key_id or input('Apple API Key ID: ').strip()
    issuer=args.issuer_id or input('Apple API Issuer ID: ').strip()
    pem=args.key_file.expanduser().read_bytes()
    api=AppleAPI(key_id,issuer,pem)
    config=json.loads((ROOT/'submission.json').read_text())
    if args.contact_file:config.update(json.loads(args.contact_file.expanduser().read_text()))
    bundle_id=config['bundleId']
    app=api.app(bundle_id)  # Authenticate/read before any Apple mutation.
    # Prove dedicated repository secret-write access before creating signing resources.
    set_secret('CARDIOFOCUS_ASC_KEY_ID',key_id)
    set_secret('CARDIOFOCUS_ASC_ISSUER_ID',issuer)
    set_secret('CARDIOFOCUS_ASC_PRIVATE_KEY_P8',pem)
    bundle=api.register_bundle(bundle_id)
    print('Bundle identifier registered: '+bundle_id)
    if app is None:
        print('Apple does not expose creation of the first app record through this API.')
        print('In your own browser open https://appstoreconnect.apple.com/apps and create an iOS app:')
        print('Name: CardioFocus: Step 1; language: English (U.S.); Bundle ID: '+bundle_id+'; SKU: cardiofocus-step1')
        input('Press Enter after the record has been created (or Ctrl+C to resume later): ')
        app=api.app(bundle_id)
        if app is None:raise SetupError('The initial app record is not visible yet. Retry after it is available; no duplicate record was created.')
    config['appStoreAppId']=app['id']
    for field,prompt in [('reviewContactFirstName','Review contact first name'),('reviewContactLastName','Review contact last name'),('reviewContactEmail','Review contact email'),('reviewContactPhone','Review contact phone with country code')]:
        if not config.get(field):config[field]=getpass.getpass(prompt+' (hidden): ').strip()
    if args.submit_review:
        if not args.build_number:raise SetupError('--build-number must identify an actual processed build')
        build=api.processed_build(app['id'],args.build_number,config['appVersion'])
        if not build or build.get('attributes',{}).get('processingState')!='VALID':raise SetupError('The selected version/build is not processed and VALID in Apple. Submission was not triggered.')
        config['signedBuildUploaded']=True
        # Derive the team from saved, owner-controlled signing state rather than inventing it.
        state=json.loads((args.state_directory.expanduser()/'signing-state.json').read_text())
        cert=api.request('GET','/v1/certificates/'+state['certificateId'])['data']
        parsed=x509.load_der_x509_certificate(base64.b64decode(cert['attributes']['certificateContent']))
        config['appleTeamId']=parsed.subject.get_attributes_for_oid(NameOID.ORGANIZATIONAL_UNIT_NAME)[0].value
        set_secret('CARDIOFOCUS_SUBMISSION_CONFIG_JSON',json.dumps(config))
        trigger('cardiofocus/apple-submit-review/'+args.build_number,'Submit processed CardioFocus build for Apple review')
        return
    team,p12,password,profile=signing(api,bundle,args.state_directory.expanduser())
    config['appleTeamId']=team;config['signedBuildUploaded']=False
    values={'CARDIOFOCUS_APPLE_TEAM_ID':team,'CARDIOFOCUS_CERTIFICATE_P12_BASE64':base64.b64encode(p12).decode(),'CARDIOFOCUS_CERTIFICATE_PASSWORD':password,'CARDIOFOCUS_PROVISIONING_PROFILE_BASE64':profile,'CARDIOFOCUS_SUBMISSION_CONFIG_JSON':json.dumps(config)}
    for name,value in values.items():set_secret(name,value)
    print('API access, exact app ID, signing and private review metadata configured. No Apple review submission has occurred.')
    if args.start_upload:
        number=choose_upload_build(api,app['id'],config['appVersion'],args.build_number)
        trigger('cardiofocus/apple-upload/'+number,'Build, sign and upload CardioFocus')
    else:print('Use --start-upload to trigger the signed macOS build after setup.')

if __name__=='__main__':
    try:main()
    except KeyboardInterrupt:sys.exit('Stopped. Existing local signing material is retained privately for retry.')
    except (SetupError,AppleAPIError) as error:sys.exit(str(error))
    except Exception as error:sys.exit('Setup stopped safely: '+type(error).__name__+'. No private key or contact data has been printed.')
