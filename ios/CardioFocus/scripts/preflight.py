from pathlib import Path
import json,plistlib,sys,re,os
root=Path(__file__).resolve().parents[1]
c=json.loads((root/'CardioFocus/Resources/curriculum.json').read_text())
assert (len(c['modules']),len(c['units']),len(c['questions']))==(12,240,480)
assert len({u['id'] for u in c['units']})==240
assert len({q['id'] for q in c['questions']})==480
assert len({q['q'] for q in c['questions']})==480
for m in c['modules']:
 assert len(m['unitIds'])==20
 assert len([q for q in c['questions'] if q['topic']==m['id']])==40
for q in c['questions']:
 assert len(q['a'])==4 and len(set(q['a']))==4 and q['correct'] in range(4)
 assert len(q['rationales'])==4
p=plistlib.loads((root/'CardioFocus/PrivacyInfo.xcprivacy').read_bytes())
assert p['NSPrivacyTracking'] is False and p['NSPrivacyCollectedDataTypes']==[]
assert p['NSPrivacyAccessedAPITypes'][0]['NSPrivacyAccessedAPITypeReasons']==['CA92.1']
icon=root/'CardioFocus/Assets.xcassets/AppIcon.appiconset/AppIcon.png'
assert icon.exists() and icon.read_bytes().startswith(b'\x89PNG\r\n\x1a\n')
assert not any('WKWebView' in f.read_text() for f in (root/'CardioFocus').rglob('*.swift'))
if '--submission' in sys.argv:
 config=json.loads((root/'submission.json').read_text());config.update(json.loads((os.environ.get('CARDIOFOCUS_SUBMISSION_CONFIG_JSON') or '{}')))
 required=['appleTeamId','appStoreAppId','bundleId','publisherName','supportURL','privacyURL','reviewContactFirstName','reviewContactLastName','reviewContactEmail','reviewContactPhone','copyright']
 missing=[key for key in required if not str(config.get(key) or '').strip()]
 if missing:sys.exit('Submission is blocked; missing actual account/contact fields: '+', '.join(missing))
 if not config.get('nativeValidationPassed'):sys.exit('Native app validation has not passed.')
 if not config.get('signedBuildUploaded'):sys.exit('No signed distribution build has been uploaded.')
print('Preflight passed: native app resources, 240 units, 480 questions, privacy manifest, icon.')
