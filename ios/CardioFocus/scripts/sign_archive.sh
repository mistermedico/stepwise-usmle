#!/bin/bash
set -euo pipefail
: "${APPLE_TEAM_ID:?Missing Apple development team ID}"
: "${ASC_KEY_ID:?Missing App Store Connect API key ID}"
: "${ASC_ISSUER_ID:?Missing App Store Connect API issuer ID}"
: "${ASC_KEY_FILE:?Missing private key file path}"
: "${CERTIFICATE_P12_BASE64:?Missing distribution certificate secret}"
: "${CERTIFICATE_PASSWORD:?Missing distribution certificate password}"
: "${PROVISIONING_PROFILE_BASE64:?Missing App Store provisioning profile secret}"
: "${APP_BUILD_NUMBER:?Missing unique build number}"

WORK="$(mktemp -d)"
KEYCHAIN="$WORK/signing.keychain-db"
export SIGNING_WORK_DIR="$WORK"
cleanup() { security delete-keychain "$KEYCHAIN" >/dev/null 2>&1 || true; rm -rf "$WORK"; }
trap cleanup EXIT
python3 - <<'PY'
import os,base64,pathlib,secrets
p=pathlib.Path(os.environ['SIGNING_WORK_DIR'])
(p/'distribution.p12').write_bytes(base64.b64decode(os.environ['CERTIFICATE_P12_BASE64'],validate=True))
(p/'profile.mobileprovision').write_bytes(base64.b64decode(os.environ['PROVISIONING_PROFILE_BASE64'],validate=True))
(p/'keychain-password').write_text(secrets.token_urlsafe(32))
PY
KEYCHAIN_PASSWORD="$(cat "$WORK/keychain-password")"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security import "$WORK/distribution.p12" -P "$CERTIFICATE_PASSWORD" -A -t cert -f pkcs12 -k "$KEYCHAIN"
security list-keychains -d user -s "$KEYCHAIN" "$HOME/Library/Keychains/login.keychain-db"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null
security cms -D -i "$WORK/profile.mobileprovision" > "$WORK/profile.plist"
python3 - <<'PY'
import os,plistlib,pathlib,json,shutil,datetime,sys
p=pathlib.Path(os.environ['SIGNING_WORK_DIR']);profile=plistlib.loads((p/'profile.plist').read_bytes())
c=json.loads(pathlib.Path('submission.json').read_text());c.update(json.loads((os.environ.get('CARDIOFOCUS_SUBMISSION_CONFIG_JSON') or '{}')));bundle=c['bundleId'];team=os.environ['APPLE_TEAM_ID']
if profile.get('TeamIdentifier',[None])[0]!=team:sys.exit('Provisioning team does not match selected Apple team')
if profile.get('Entitlements',{}).get('application-identifier')!=team+'.'+bundle:sys.exit('Provisioning profile does not match bundle ID')
if profile.get('Entitlements',{}).get('get-task-allow'):sys.exit('Development profiles are not suitable for App Store distribution')
if 'ProvisionedDevices' in profile or profile.get('ProvisionsAllDevices'):sys.exit('Expected an App Store distribution profile, not ad hoc or enterprise')
if profile['ExpirationDate']<datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None):sys.exit('Provisioning profile has expired')
dest=pathlib.Path.home()/'Library/MobileDevice/Provisioning Profiles';dest.mkdir(parents=True,exist_ok=True)
shutil.copy(p/'profile.mobileprovision',dest/(profile['UUID']+'.mobileprovision'))
(p/'profile-name').write_text(profile['Name'])
plistlib.dump({'method':'app-store-connect','signingStyle':'manual','teamID':team,'uploadSymbols':True,'provisioningProfiles':{bundle:profile['Name']}},open('ExportOptions.plist','wb'))
PY
PROFILE_NAME="$(cat "$WORK/profile-name")"
BUNDLE_ID="$(python3 -c 'import json,os;c=json.load(open("submission.json"));c.update(json.loads((os.environ.get("CARDIOFOCUS_SUBMISSION_CONFIG_JSON") or "{}")));print(c["bundleId"])')"
mkdir -p build
xcodebuild archive -project CardioFocus.xcodeproj -scheme CardioFocus -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/CardioFocus.xcarchive \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  CURRENT_PROJECT_VERSION="$APP_BUILD_NUMBER" CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY='Apple Distribution' PROVISIONING_PROFILE_SPECIFIER="$PROFILE_NAME"
xcodebuild -exportArchive -archivePath build/CardioFocus.xcarchive -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist
