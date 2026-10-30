"""Record actual Apple state after submission; never substitutes a local success flag."""
from pathlib import Path
import os,json,sys
from asc_api import AppleAPI
root=Path(__file__).resolve().parents[1]
c=json.loads((root/'submission.json').read_text());c.update(json.loads(os.environ.get('CARDIOFOCUS_SUBMISSION_CONFIG_JSON') or '{}'))
api=AppleAPI.from_environment();app=api.app(c['bundleId'])
if not app:sys.exit('No App Store app record exists for this bundle ID.')
number=os.environ.get('APP_BUILD_NUMBER','')
if not number:sys.exit('Actual processed build number is required.')
accepted=api.review_receipts(app['id'],number,c['appVersion'])
receipt={'appId':app['id'],'bundleId':c['bundleId'],'requestedBuild':number,'reviewSubmissions':accepted}
out=root/'build/apple-review-receipt.json';out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(receipt,indent=2))
print(json.dumps(receipt,indent=2))
if not accepted:sys.exit('Apple has not returned a submitted review state; do not report submission success.')
