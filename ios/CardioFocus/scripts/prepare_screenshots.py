"""Copy actual xcresult attachments into App Store locale folders without altering pixels."""
from pathlib import Path
import sys,json,shutil,hashlib
from PIL import Image
root=Path(__file__).resolve().parents[1]
if len(sys.argv)<2:sys.exit('Usage: prepare_screenshots.py <downloaded-validation-artifact-directory> [run-id]')
source=Path(sys.argv[1]);dest=root/'appstore/screenshots/en-US';dest.mkdir(parents=True,exist_ok=True)
records=[]
accepted_phone={(1320,2868),(2868,1320),(1290,2796),(2796,1290),(1260,2736),(2736,1260)}
accepted_pad={(2064,2752),(2752,2064),(2048,2732),(2732,2048)}
for manifest in sorted(source.rglob('manifest.json')):
 if manifest.parent.name not in ['screenshots','ipad-screenshots']:continue
 groups=json.loads(manifest.read_text())
 for group in groups:
  for attachment in group.get('attachments',[]):
   if attachment.get('isAssociatedWithFailure'):continue
   f=manifest.parent/attachment['exportedFileName']
   if f.suffix.lower()!='.png':continue
   image=Image.open(f);size=image.size
   kind='ipad' if 'iPad' in attachment.get('deviceName','') else 'iphone'
   if size not in (accepted_pad if kind=='ipad' else accepted_phone):sys.exit(f'Unrecognized {kind} screenshot size: {size}')
   if image.mode=='RGBA' and image.getextrema()[-1]!=(255,255):sys.exit('Screenshot has transparent pixels')
   suggested=attachment.get('suggestedHumanReadableName',f.name).split('_0_')[0]
   if kind=='iphone' and suggested=='01-Home-native':continue
   target=dest/f'{kind}-{suggested}.png';shutil.copy2(f,target)
   records.append({'file':str(target.relative_to(root)),'device':attachment.get('deviceName'),'pixels':list(size),'sourceTest':group.get('testIdentifier'),'sha256':hashlib.sha256(f.read_bytes()).hexdigest()})
if not records:sys.exit('No screenshot attachments found')
report={'status':'actual-native-simulator-screenshots','runId':sys.argv[2] if len(sys.argv)>2 else None,'files':records,'hasIPhone':any(r['file'].split('/')[-1].startswith('iphone') for r in records),'hasIPad':any(r['file'].split('/')[-1].startswith('ipad') for r in records),'pixelEditing':False}
(root/'appstore/screenshot-evidence.json').write_text(json.dumps(report,indent=2))
print(json.dumps({'copied':len(records),'iPhone':report['hasIPhone'],'iPad':report['hasIPad']},indent=2))
