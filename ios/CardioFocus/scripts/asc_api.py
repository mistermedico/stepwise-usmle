"""Small App Store Connect API client. Never prints tokens or private key material."""
from __future__ import annotations
import base64,json,os,time,urllib.request,urllib.parse,urllib.error
from pathlib import Path
from cryptography.hazmat.primitives import hashes,serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature

BASE='https://api.appstoreconnect.apple.com'
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,req,fp,code,msg,headers,newurl):
        raise AppleAPIError(code,['REDIRECT_REFUSED'])

def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode().rstrip('=')

class AppleAPIError(RuntimeError):
    def __init__(self,status:int,codes:list[str]):
        self.status=status;self.codes=codes
        super().__init__('Apple API HTTP '+str(status)+' ['+', '.join(codes)+']')

class AppleAPI:
    def __init__(self,key_id:str,issuer_id:str,private_key:bytes,opener=None,clock=time.time):
        if not key_id or not issuer_id or not private_key:raise ValueError('Missing Apple API credentials')
        self.key_id=key_id;self.issuer_id=issuer_id
        self.key=serialization.load_pem_private_key(private_key,password=None)
        if not isinstance(self.key,ec.EllipticCurvePrivateKey) or not isinstance(self.key.curve,ec.SECP256R1):
            raise ValueError('Expected an Apple ES256/P-256 .p8 key')
        self.opener=opener or urllib.request.build_opener(NoRedirect()).open;self.clock=clock
    @classmethod
    def from_environment(cls):
        key_id=os.environ.get('ASC_KEY_ID','');issuer=os.environ.get('ASC_ISSUER_ID','')
        pem=os.environ.get('ASC_PRIVATE_KEY_P8','').encode()
        if not pem and os.environ.get('ASC_KEY_FILE'):pem=Path(os.environ['ASC_KEY_FILE']).read_bytes()
        if not pem and os.environ.get('ASC_PRIVATE_KEY_BASE64'):pem=base64.b64decode(os.environ['ASC_PRIVATE_KEY_BASE64'],validate=True)
        return cls(key_id,issuer,pem)
    def token(self):
        now=int(self.clock())
        header=b64url(json.dumps({'alg':'ES256','kid':self.key_id,'typ':'JWT'},separators=(',',':')).encode())
        payload=b64url(json.dumps({'iss':self.issuer_id,'iat':now-5,'exp':now+600,'aud':'appstoreconnect-v1'},separators=(',',':')).encode())
        message=(header+'.'+payload).encode();r,s=decode_dss_signature(self.key.sign(message,ec.ECDSA(hashes.SHA256())))
        signature=r.to_bytes(32,'big')+s.to_bytes(32,'big')
        return header+'.'+payload+'.'+b64url(signature)
    def request(self,method,path,body=None,query=None):
        # Restrict credentials to Apple's documented API origin, including pagination links.
        if path.startswith('https://'):
            u=urllib.parse.urlsplit(path)
            if u.scheme!='https' or u.netloc!='api.appstoreconnect.apple.com':raise ValueError('Unexpected API origin')
            url=path
        else:
            if not path.startswith('/v1/'):raise ValueError('Expected an App Store Connect v1 API path')
            url=BASE+path
        if query:url+='?'+urllib.parse.urlencode(query)
        data=json.dumps(body).encode() if body is not None else None
        req=urllib.request.Request(url,data=data,method=method,headers={'Authorization':'Bearer '+self.token(),'Content-Type':'application/json','Accept':'application/json'})
        try:
            with self.opener(req,timeout=45) as response:
                raw=response.read();return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as error:
            try:parsed=json.loads(error.read());codes=[e.get('code','UNKNOWN') for e in parsed.get('errors',[])]
            except Exception:codes=['UNPARSEABLE_RESPONSE']
            raise AppleAPIError(error.code,codes) from None
    def collection(self,path,query=None):
        result=[];next_path=path
        while next_path:
            page=self.request('GET',next_path,query=query);query=None
            result.extend(page.get('data',[]));next_path=page.get('links',{}).get('next')
        return result
    def app(self,bundle_id):
        apps=self.collection('/v1/apps',{'filter[bundleId]':bundle_id,'limit':200})
        exact=[a for a in apps if a.get('attributes',{}).get('bundleId')==bundle_id]
        if len(exact)>1:raise ValueError('More than one matching app returned')
        return exact[0] if exact else None
    def bundle(self,identifier):
        found=self.collection('/v1/bundleIds',{'filter[identifier]':identifier,'limit':200})
        exact=[b for b in found if b.get('attributes',{}).get('identifier')==identifier]
        if len(exact)>1:raise ValueError('More than one matching bundle ID returned')
        return exact[0] if exact else None
    def register_bundle(self,identifier,name='CardioFocus'):
        existing=self.bundle(identifier)
        if existing:return existing
        return self.request('POST','/v1/bundleIds',{'data':{'type':'bundleIds','attributes':{'identifier':identifier,'name':name,'platform':'IOS'}}})['data']
    def processed_build(self,app_id,build_number,marketing_version):
        found=self.collection('/v1/builds',{'filter[app]':app_id,'filter[version]':str(build_number),'filter[preReleaseVersion.version]':marketing_version,'filter[preReleaseVersion.platform]':'IOS','limit':200})
        return found[0] if len(found)==1 else None

    def review_receipts(self,app_id,build_number,marketing_version):
        build=self.processed_build(app_id,build_number,marketing_version)
        if not build or build.get('attributes',{}).get('processingState')!='VALID':return []
        submissions=self.collection('/v1/reviewSubmissions',{'filter[app]':app_id,'filter[platform]':'IOS','limit':200})
        accepted=[]
        for submission in submissions:
            if submission.get('attributes',{}).get('state') not in ['WAITING_FOR_REVIEW','IN_REVIEW','COMPLETING','COMPLETE']:continue
            items=self.collection('/v1/reviewSubmissions/'+submission['id']+'/items',{'limit':200,'include':'appStoreVersion'})
            for item in items:
                version=item.get('relationships',{}).get('appStoreVersion',{}).get('data')
                if not version:continue
                linked=self.request('GET','/v1/appStoreVersions/'+version['id']+'/build').get('data')
                if linked and linked['id']==build['id']:
                    accepted.append({'id':submission['id'],'state':submission['attributes']['state'],'submittedDate':submission['attributes'].get('submittedDate'),'appStoreVersionId':version['id'],'buildId':build['id']});break
        return accepted
