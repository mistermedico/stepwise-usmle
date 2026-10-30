# CardioFocus for iPhone and iPad

Native SwiftUI application for independent English-language USMLE Step 1 cardiology study.

The curriculum contains 240 distinct units, 480 paired questions, and 240 recall cards. Lessons, questions, explanations, bookmarks, and progress work from bundled data without a runtime service. The application does not embed the web edition and has no login, advertising, analytics SDK, purchase system, or HealthKit integration.

## Current submission state

Not submitted to Apple. Native code, resources, privacy manifest, metadata, tests, and signing/upload automation are prepared. Account access, publisher/review contact details, signing material, signed binary upload, final App Store declarations, and actual submission remain outstanding until verified. Do not treat a simulator app or unsigned build as an App Store IPA.

The content is original educational material and has not passed independent medical expert review. This is disclosed in the app and review notes. The counts describe paired concept exercises, not 480 unrelated clinical scenarios or complete examination coverage.

## Build on macOS

Use Xcode 26 or later with an iOS 26+ SDK, XcodeGen, and a simulator runtime. The deployment target is iOS 17.

```
python3 scripts/preflight.py
xcodegen generate
xcodebuild -project CardioFocus.xcodeproj -scheme CardioFocus \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Run the scheme's unit and UI tests on an available iPhone and iPad simulator. `.github/workflows/ios-validate.yml` performs cloud validation. On the isolated `stepwise-usmle` integration branch, the app lives in `ios/CardioFocus` and the workflow is `.github/workflows/cardiofocus-ios.yml`.

## Apple account access

Use an Apple Developer Program account with App Store Connect privileges sufficient to create and submit the app. Sign in directly using the secure browser setup offered in the conversation. Never paste passwords, 2FA codes, private keys, certificate passwords, or session cookies into chat, source code, an issue, or an application artifact.

Owner-controlled missing fields are listed in the public template `submission.json`. Supply actual publisher and review-contact values through the GitHub Actions secret `CARDIOFOCUS_SUBMISSION_CONFIG_JSON` (a JSON object overriding that template); do not commit personal contact details to the public integration branch. Team IDs and app IDs must be copied from the actual selected Apple account. The local bundle ID is provisional until registered in that account. Genuine review contact details and publisher copyright are required; they are deliberately not invented.

## Signing and upload

Configure these as GitHub Actions secrets for the selected repository, not as committed files:

- `CARDIOFOCUS_SUBMISSION_CONFIG_JSON`: actual account/contact metadata and readiness evidence, supplied privately as a JSON object.
- `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY_BASE64`: an App Store Connect API key with the required role.
- `APPLE_TEAM_ID`: the actual distribution team.
- `CERTIFICATE_P12_BASE64`, `CERTIFICATE_PASSWORD`: an Apple Distribution certificate and its private key exported as PKCS#12.
- `PROVISIONING_PROFILE_BASE64`: an App Store distribution profile for the exact bundle ID and certificate.

On the upload-trigger branch, the CI run number is used as a unique build number. For the submit-review trigger branch, set repository variable `CARDIOFOCUS_REVIEW_BUILD_NUMBER` to the actual processed build number; do not use a new arbitrary run number. Manual dispatch accepts the explicit build-number input.

The release workflow validates profile type, bundle, team, and expiry, imports signing material into an ephemeral runner keychain, archives and exports a real distribution IPA, and uploads it using Fastlane. The certificate/profile and API key are required; no production credentials are included in this package.

A repository workflow on a new branch may not expose a manual-dispatch UI until that workflow is present on the default branch. Keep the integration branch isolated and use the documented release-trigger branches or merge only when the repository owner chooses to do so. Do not modify the existing web app's production branch merely to activate a workflow.

`fastlane ios submit_review` targets an already processed build and keeps release manual after approval. Its preflight checks require actual account/contact values, signed-build evidence, device QA, and actual iPhone/iPad screenshots. Complete App Store privacy, age-rating, category, content-rights, export, availability and pricing fields in the actual account. The application is intended to be free with no purchases, with worldwide availability where permitted; do not infer legal trader status or sign legal agreements on the owner's behalf.

## App Store material

- `appstore/en-US/`: English name, subtitle, description, keywords and real public policy/support URLs.
- `appstore/review_notes.txt`: review navigation, data handling and medical-content limitations.
- `CardioFocus/PrivacyInfo.xcprivacy`: UserDefaults required-reason API declaration (`CA92.1`), no tracking or collected-data declarations for this native build.
- `CardioFocus/Resources/privacy.txt`: in-app privacy policy.
- `submission.json`: actual readiness/account fields, including explicit false values for uncompleted steps.

Do not label generated mockups as app screenshots. Validation captures native simulator screens; physical-device QA and final App Store screenshot sizing remain separate checks.

## Public support and privacy

- App/web preview: https://cardio-step1-he.mistermedico.chatgpt.site/
- Support: https://cardio-step1-he.mistermedico.chatgpt.site/support.html
- Privacy: https://cardio-step1-he.mistermedico.chatgpt.site/privacy.html

Support requests are public GitHub issues. Do not post personal health information. Native study records stay on device unless the learner initiates an export. Hosting and external-link destinations have their own access logs and policies.
