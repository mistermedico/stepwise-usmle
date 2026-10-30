import sys,json,base64,io,unittest,tempfile,datetime,contextlib,urllib.error,os
from pathlib import Path
from unittest.mock import Mock,patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from cryptography import x509
from cryptography.hazmat.primitives import serialization,hashes
from cryptography.hazmat.primitives.asymmetric import ec,rsa
from cryptography.hazmat.primitives.asymmetric.utils import encode_dss_signature
from cryptography.hazmat.primitives.serialization import pkcs12
from cryptography.x509.oid import NameOID
from asc_api import AppleAPI,AppleAPIError,NoRedirect
import configure_apple_api as setup
from asc_metadata import apply_age_rating

def unb64(value):return base64.urlsafe_b64decode(value+'='*((4-len(value)%4)%4))
class Response:
 def __init__(self,value):self.value=value
 def read(self):return json.dumps(self.value).encode()
 def __enter__(self):return self
 def __exit__(self,*args):pass

class APIClientTests(unittest.TestCase):
 def setUp(self):
  self.key=ec.generate_private_key(ec.SECP256R1());self.pem=self.key.private_bytes(serialization.Encoding.PEM,serialization.PrivateFormat.PKCS8,serialization.NoEncryption())
  self.api=AppleAPI('TESTKEY','TESTISSUER',self.pem,clock=lambda:1000000)
 def test_jwt_uses_raw_es256_signature_and_correct_audience(self):
  header,payload,signature=self.api.token().split('.')
  self.assertEqual(json.loads(unb64(header))['alg'],'ES256')
  claims=json.loads(unb64(payload));self.assertEqual(claims['aud'],'appstoreconnect-v1');self.assertEqual(claims['iss'],'TESTISSUER')
  self.assertLessEqual(claims['exp']-claims['iat'],1200)
  raw=unb64(signature);self.assertEqual(len(raw),64)
  der=encode_dss_signature(int.from_bytes(raw[:32],'big'),int.from_bytes(raw[32:],'big'))
  self.key.public_key().verify(der,(header+'.'+payload).encode(),ec.ECDSA(hashes.SHA256()))
 def test_unexpected_origins_and_redirects_are_rejected(self):
  for url in ['https://example.com/v1/apps','https://api.appstoreconnect.apple.com.evil.test/v1/apps','http://api.appstoreconnect.apple.com/v1/apps']:
   with self.assertRaises(ValueError):self.api.request('GET',url)
  with self.assertRaises(AppleAPIError):NoRedirect().redirect_request(None,None,302,'',{},'https://example.com')
 def test_http_errors_do_not_print_response_secrets(self):
  error=urllib.error.HTTPError('https://api.appstoreconnect.apple.com/v1/apps',401,'Unauthorized',{},io.BytesIO(b'{"errors":[{"code":"AUTHENTICATION_ERROR","detail":"SYNTHETIC_SECRET"}]}'))
  self.api.opener=Mock(side_effect=error)
  with self.assertRaises(AppleAPIError) as ctx:self.api.request('GET','/v1/apps')
  self.assertNotIn('SYNTHETIC_SECRET',str(ctx.exception));self.assertEqual(ctx.exception.status,401)
 def test_exact_bundle_match_is_required(self):
  self.api.collection=Mock(return_value=[{'id':'wrong','attributes':{'bundleId':'com.test.other'}}])
  self.assertIsNone(self.api.app('com.test.exact'))
 def test_existing_bundle_registration_is_idempotent(self):
  self.api.bundle=Mock(return_value={'id':'EXISTING'});self.api.request=Mock()
  self.assertEqual(self.api.register_bundle('com.test.app')['id'],'EXISTING');self.api.request.assert_not_called()
 def test_bundle_creation_uses_documented_ios_payload(self):
  self.api.bundle=Mock(return_value=None);self.api.request=Mock(return_value={'data':{'id':'NEW'}})
  self.api.register_bundle('com.test.app')
  method,path,body=self.api.request.call_args.args
  self.assertEqual((method,path),('POST','/v1/bundleIds'));self.assertEqual(body['data']['attributes']['platform'],'IOS')
 def test_pagination_cannot_leak_auth_to_another_origin(self):
  self.api.opener=Mock(return_value=Response({'data':[],'links':{'next':'https://example.com/next'}}))
  with self.assertRaises(ValueError):self.api.collection('/v1/apps')
  self.assertEqual(self.api.opener.call_count,1)
 def test_review_receipt_does_not_accept_an_unrelated_old_build(self):
  def collection(path,query=None):
   if path=='/v1/builds':
    self.assertEqual(query['filter[version]'],'42');self.assertEqual(query['filter[preReleaseVersion.version]'],'1.0.0')
    return [{'id':'BUILD42','attributes':{'processingState':'VALID'}}]
   if path=='/v1/reviewSubmissions':return [{'id':'OLD','attributes':{'state':'COMPLETE'}},{'id':'NEW','attributes':{'state':'WAITING_FOR_REVIEW'}},{'id':'DRAFT','attributes':{'state':'READY_FOR_REVIEW'}}]
   if path.endswith('/OLD/items'):return [{'relationships':{'appStoreVersion':{'data':{'id':'VOLD'}}}}]
   if path.endswith('/NEW/items'):return [{'relationships':{'appStoreVersion':{'data':{'id':'VNEW'}}}}]
   self.fail('Unexpected collection '+path)
  self.api.collection=collection
  self.api.request=lambda method,path:{'data':{'id':'BUILD42' if '/VNEW/' in path else 'BUILD01'}}
  receipts=self.api.review_receipts('APP','42','1.0.0');self.assertEqual([r['id'] for r in receipts],['NEW']);self.assertEqual(receipts[0]['buildId'],'BUILD42')
 def test_unprocessed_build_cannot_produce_review_receipt(self):
  self.api.processed_build=Mock(return_value={'id':'B','attributes':{'processingState':'PROCESSING'}})
  self.api.collection=Mock();self.assertEqual(self.api.review_receipts('A','1','1.0.0'),[]);self.api.collection.assert_not_called()

class AgeMetadataTests(unittest.TestCase):
 def test_rating_targets_only_the_exact_editable_app(self):
  api=Mock();api.app.return_value={'id':'APP'};api.collection.return_value=[{'id':'INFO','attributes':{'state':'PREPARE_FOR_SUBMISSION'}}]
  api.request.side_effect=[{'data':{'id':'RATING'}},{'data':{'id':'RATING'}}]
  result=apply_age_rating(api,'com.test.exact',{'medicalOrTreatmentInformation':'FREQUENT_OR_INTENSE'})
  self.assertEqual(result['appId'],'APP');self.assertEqual(api.request.call_args.args[0],'PATCH');self.assertEqual(api.request.call_args.args[1],'/v1/ageRatingDeclarations/RATING')
 def test_ambiguous_app_info_does_not_mutate_any_declaration(self):
  api=Mock();api.app.return_value={'id':'APP'};api.collection.return_value=[{'id':'ONE','attributes':{'state':'PREPARE_FOR_SUBMISSION'}},{'id':'TWO','attributes':{'state':'PREPARE_FOR_SUBMISSION'}}]
  with self.assertRaises(ValueError):apply_age_rating(api,'com.test.exact',{})
  api.request.assert_not_called()

class SigningAPI:
 issuer_id='TEST-ISSUER'
 def __init__(self):self.cert=None;self.profile=None;self.cert_creations=0;self.profile_creations=0
 def collection(self,path,query=None):
  if path=='/v1/certificates':return [self.cert] if self.cert else []
  if path.endswith('/certificates'):return [self.cert]
  raise AssertionError(path)
 def request(self,method,path,body=None):
  assert method!='DELETE','Certificates must never be automatically revoked'
  if method=='POST' and path=='/v1/certificates':
   self.cert_creations+=1;assert body['data']['attributes']['certificateType']=='DISTRIBUTION'
   csr=x509.load_pem_x509_csr(body['data']['attributes']['csrContent'].encode())
   ca=rsa.generate_private_key(public_exponent=65537,key_size=2048)
   now=datetime.datetime.now(datetime.timezone.utc)
   cert=x509.CertificateBuilder().subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME,'TEST'),x509.NameAttribute(NameOID.ORGANIZATIONAL_UNIT_NAME,'TEAMTEST')])).issuer_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME,'TEST-CA')])).public_key(csr.public_key()).serial_number(1).not_valid_before(now-datetime.timedelta(days=1)).not_valid_after(now+datetime.timedelta(days=30)).sign(ca,hashes.SHA256())
   self.cert={'id':'CERT','attributes':{'certificateContent':base64.b64encode(cert.public_bytes(serialization.Encoding.DER)).decode(),'expirationDate':(now+datetime.timedelta(days=30)).isoformat()}}
   return {'data':self.cert}
  if path=='/v1/certificates/CERT':return {'data':self.cert}
  if method=='POST' and path=='/v1/profiles':
   self.profile_creations+=1;a=body['data'];assert a['attributes']['profileType']=='IOS_APP_STORE';assert a['relationships']['bundleId']['data']['id']=='BUNDLE';assert a['relationships']['certificates']['data'][0]['id']=='CERT';assert 'devices' not in a['relationships']
   self.profile={'id':'PROFILE','attributes':{'profileContent':base64.b64encode(b'SYNTHETIC_PROFILE').decode(),'profileState':'ACTIVE','expirationDate':(datetime.datetime.now(datetime.timezone.utc)+datetime.timedelta(days=30)).isoformat()}}
   return {'data':self.profile}
  if path=='/v1/profiles/PROFILE':return {'data':self.profile}
  if path=='/v1/profiles/PROFILE/bundleId':return {'data':{'id':'BUNDLE'}}
  raise AssertionError((method,path))

class OwnerSetupTests(unittest.TestCase):
 def test_signing_reuses_owned_certificate_and_profile(self):
  with tempfile.TemporaryDirectory() as directory:
   api=SigningAPI();path=Path(directory)/'private'
   team,p12,password,profile=setup.signing(api,{'id':'BUNDLE'},path)
   self.assertEqual(team,'TEAMTEST');key,cert,extra=pkcs12.load_key_and_certificates(p12,password.encode());self.assertIsNotNone(key);self.assertIsNotNone(cert)
   setup.signing(api,{'id':'BUNDLE'},path)
   self.assertEqual(api.cert_creations,1);self.assertEqual(api.profile_creations,1)
   if os.name!='nt':self.assertEqual((path/'distribution-key.pem').stat().st_mode&0o777,0o600)
 def test_wrong_issuer_signing_state_is_not_reused(self):
  with tempfile.TemporaryDirectory() as directory:
   path=Path(directory);(path/'signing-state.json').write_text('{"issuerId":"ANOTHER-TEAM"}')
   with self.assertRaises(setup.SetupError):setup.signing(SigningAPI(),{'id':'BUNDLE'},path)
 def test_secret_payload_is_stdin_only_and_not_printed(self):
  output=io.StringIO()
  with patch.object(setup,'gh',return_value=b'') as call,contextlib.redirect_stdout(output):setup.set_secret('CARDIOFOCUS_TEST','SYNTHETIC_PRIVATE_VALUE')
  self.assertNotIn('SYNTHETIC_PRIVATE_VALUE',output.getvalue());self.assertNotIn('SYNTHETIC_PRIVATE_VALUE',' '.join(call.call_args.args[0]));self.assertEqual(call.call_args.args[1],b'SYNTHETIC_PRIVATE_VALUE')
 def test_new_upload_build_is_newer_than_existing_app_versions(self):
  api=Mock();api.collection.return_value=[{'attributes':{'version':'2.99.1'}},{'attributes':{'version':'3'}}]
  self.assertEqual(setup.choose_upload_build(api,'APP','1.0.0'),'4')
  with self.assertRaises(setup.SetupError):setup.choose_upload_build(api,'APP','1.0.0','2')
  self.assertEqual(setup.choose_upload_build(api,'APP','1.0.0','5'),'5')
 def test_private_writer_refuses_symlink(self):
  if os.name=='nt':self.skipTest('POSIX O_NOFOLLOW check')
  with tempfile.TemporaryDirectory() as directory:
   target=Path(directory)/'target';target.write_text('keep');link=Path(directory)/'link';link.symlink_to(target)
   with self.assertRaises(OSError):setup.private_write(link,b'overwrite')
   self.assertEqual(target.read_text(),'keep')

if __name__=='__main__':unittest.main()
