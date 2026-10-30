"""Read-only API/credential readiness report, suitable for public CI logs."""
import os,json,sys
from pathlib import Path
from asc_api import AppleAPI,AppleAPIError

root=Path(__file__).resolve().parents[1]
c=json.loads((root/'submission.json').read_text())
c.update(json.loads(os.environ.get('CARDIOFOCUS_SUBMISSION_CONFIG_JSON') or '{}'))
report={'status':'not-submitted','apiAuthenticated':False,'bundleId':c['bundleId'],'appRecord':None,'missing':[]}
for key in ['ASC_KEY_ID','ASC_ISSUER_ID']:
    if not os.environ.get(key):report['missing'].append(key)
if not any(os.environ.get(k) for k in ['ASC_PRIVATE_KEY_P8','ASC_PRIVATE_KEY_BASE64','ASC_KEY_FILE']):report['missing'].append('ASC_PRIVATE_KEY_P8')
try:
    if report['missing']:report['status']='credentials-required'
    else:
        api=AppleAPI.from_environment();app=api.app(c['bundleId']);report['apiAuthenticated']=True
        bundle=api.bundle(c['bundleId']);report['bundleRegistered']=bool(bundle)
        report['appRecord']={'id':app['id'],'bundleId':app['attributes']['bundleId']} if app else None
        report['status']='api-ready' if app else 'initial-app-record-required'
        report['signingSecretsPresent']={name:bool(os.environ.get(name)) for name in ['APPLE_TEAM_ID','CERTIFICATE_P12_BASE64','CERTIFICATE_PASSWORD','PROVISIONING_PROFILE_BASE64']}
except AppleAPIError as e:report.update(status='apple-api-error',httpStatus=e.status,errorCodes=e.codes)
except Exception as e:report.update(status='configuration-error',errorType=type(e).__name__)
out=root/'build/api-readiness.json';out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
sys.exit(0 if report['status']=='api-ready' else 2)
