# CardioFocus: API-only publishing setup

The app remains **not submitted**. No TinyFish or Apple Account password/session cookie is used by this route.

## Verified current blocker

The read-only GitHub Actions run https://github.com/mistermedico/stepwise-usmle/actions/runs/41064630743 found no configured Key ID, Issuer ID, or private API key in the selected project. It stopped before authenticating to Apple or changing Apple resources. The current integration also cannot manage repository secrets (GitHub returns HTTP 403), so the owner must perform the one-time credential setup locally or in GitHub settings.

## One-time owner setup

Use an existing **team App Store Connect API key**, or generate one at:

https://appstoreconnect.apple.com/access/integrations/api

The key must be allowed to access the app and the Certificates, Identifiers & Profiles API. If Apple denies certificate creation, no existing certificate is revoked. Save the `.p8` download privately; Apple typically offers the private-key download only once. Record its Key ID and Issuer ID. Never paste the private key into chat, source, issues, or public logs.

On the owner's Mac, Windows, or Linux computer, install Python 3.10+ and the GitHub CLI. Authenticate `gh` as an account permitted to manage Actions secrets and contents in `mistermedico/stepwise-usmle`. A personal/fine-grained credential needs the appropriate repository Secrets, Contents, and Actions permissions. The ChatGPT integration's narrower credential is not sufficient to manage secrets.

From the extracted setup package:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install 'cryptography>=43,<47'
gh auth login
.venv/bin/python scripts/configure_apple_api.py \
  --key-file "$HOME/Downloads/AuthKey_YOUR_KEY_ID.p8" \
  --contact-file private-review-contact.json \
  --start-upload
```

On Windows, use `py -m venv .venv` and `.venv\Scripts\python.exe` in place of `.venv/bin/python`. The helper prompts for Key ID and Issuer ID if not passed explicitly. The separately delivered `private-review-contact.json` contains the review contact already provided by the owner; do not commit it. It is passed to GitHub Secrets, not embedded in the application.

The helper:

1. Authenticates to the exact Apple API and finds the app by exact bundle identifier.
2. Reuses or registers `com.mistermedico.cardiofocus`.
3. If the initial app record is missing, pauses for the owner to create that record in their ordinary browser. The API does not expose this creation operation.
4. Creates or reuses owner-controlled distribution signing material. It never revokes other certificates or overwrites existing Git branches.
5. Verifies the team from Apple's distribution certificate and the bundle/certificate relationships of the provisioning profile.
6. Stores dedicated `CARDIOFOCUS_*` secrets using `gh secret set` over stdin. It does not overwrite another app's generic `ASC_*` secrets.
7. Creates an isolated release-trigger branch so GitHub's macOS runner can build, sign, and upload. The existing web app's main branch remains untouched.

The private distribution key and recovery metadata are retained under `~/.cardiofocus-signing` with restrictive permissions on POSIX systems. Protect that directory; retaining the key permits retries without issuing duplicate certificates. Do not publish it or include it in project archives.

## First app record and account declarations

Apple's official OpenAPI 4.5.1 specification, checked 30 October 2026, exposes GET but no POST on `/v1/apps`. If there is no app record, create it once at https://appstoreconnect.apple.com/apps using:

- Platform: iOS
- Name: CardioFocus: Step 1
- Primary language: English (U.S.)
- Bundle ID: com.mistermedico.cardiofocus
- SKU: cardiofocus-step1

The helper rechecks the actual API record after you create it; it never fabricates an app ID. App Privacy and account/legal declarations not exposed through the API must also be completed by the owner in Apple's normal website. The native build does not collect or track study data. Do not make a false trader-status declaration or accept legal agreements through this helper.

Age-rating answers are applied through Apple's supported API. The prepared answers identify frequent educational medical information and infrequent references to alcohol/tobacco/drug use in medical teaching; Apple computes the numerical rating. They do not assert independent medical approval. Final declarations must remain accurate for the actual distributed app.

## Submit a processed build

After the signed upload has finished and Apple reports the build as `VALID`:

```sh
.venv/bin/python scripts/configure_apple_api.py \
  --key-file "$HOME/Downloads/AuthKey_YOUR_KEY_ID.p8" \
  --contact-file private-review-contact.json \
  --submit-review --build-number ACTUAL_BUILD_NUMBER
```

The helper checks the exact app, marketing version, and processed build before triggering review. The macOS workflow applies metadata and seven actual native screenshots, selects free pricing, submits using Fastlane/API, and keeps release manual after approval. It emits `apple-review-receipt.json` only after querying a submitted Apple review state that is linked to the exact selected build. An old review for another build or a locally set Boolean cannot be used as proof of submission.

## Secrets configured by the helper

- CARDIOFOCUS_ASC_KEY_ID
- CARDIOFOCUS_ASC_ISSUER_ID
- CARDIOFOCUS_ASC_PRIVATE_KEY_P8
- CARDIOFOCUS_APPLE_TEAM_ID
- CARDIOFOCUS_CERTIFICATE_P12_BASE64
- CARDIOFOCUS_CERTIFICATE_PASSWORD
- CARDIOFOCUS_PROVISIONING_PROFILE_BASE64
- CARDIOFOCUS_SUBMISSION_CONFIG_JSON

Private review-contact fields are masked individually in public CI logs. Runtime private-key files are removed after the job; signing uses an ephemeral keychain. No secret values are included in downloadable source archives.

## Evidence and validation limits

Sixteen mocked local tests cover JWT signatures, origin/redirect restrictions, exact app selection, bundle-ID idempotency, reusable signing material, private file permissions, secret stdin handling, editable age-rating selection, and exact-build review receipts. These tests do not prove live Apple API access; live authentication remains blocked until an owner-controlled key is configured. Native Swift sources and curriculum are unchanged from the passing iPhone/iPad validation run 41013755585.

Official API contract: https://developer.apple.com/sample-code/app-store-connect/app-store-connect-openapi-specification.zip
