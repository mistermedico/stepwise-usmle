# Releasing Strainwave

> עברית: [`RELEASE.he.md`](RELEASE.he.md) — the same steps, in Hebrew.

Everything else in this project is automated. This file covers the four things
that genuinely need a human with an Apple Developer account, in the order you
should do them.

1. [Secrets the pipeline needs](#1-secrets-the-pipeline-needs)
2. [Creating the Apple files](#2-creating-the-apple-files)
3. [Switching the ad SDK on](#3-switching-the-ad-sdk-on)
4. [First submission](#4-first-submission)

---

## 1. Secrets the pipeline needs

Add these under **Settings → Secrets and variables → Actions**, in the
`release` environment (the `testflight` job is scoped to it).

| Secret | What it is | Where it comes from |
| --- | --- | --- |
| `APPLE_TEAM_ID` | Your ten-character Team ID, e.g. `A1B2C3D4E5` | developer.apple.com → Membership details |
| `IOS_DISTRIBUTION_CERT_P12` | Base64 of your Apple Distribution certificate, exported as `.p12` | § 2.2 below |
| `IOS_DISTRIBUTION_CERT_PASSWORD` | The password you set when exporting that `.p12` | You choose it in § 2.2 |
| `IOS_PROVISIONING_PROFILE` | Base64 of the App Store provisioning profile | § 2.3 below |
| `IOS_PROVISIONING_PROFILE_NAME` | The profile's **name**, exactly as shown in the portal | § 2.3 below |
| `KEYCHAIN_PASSWORD` | Any random string — it only protects a throwaway keychain on the runner | `openssl rand -base64 24` |
| `APP_STORE_CONNECT_KEY_ID` | The API key's ten-character ID | § 2.4 below |
| `APP_STORE_CONNECT_ISSUER_ID` | The issuer UUID shown above the key list | § 2.4 below |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Base64 of the downloaded `AuthKey_XXXXXXXXXX.p8` | § 2.4 below |

To base64 a file for pasting into a secret:

```bash
base64 -i Certificates.p12 | pbcopy      # macOS
base64 -w0 Certificates.p12              # Linux
```

Paste the result as the secret's value, with no line breaks and no trailing
newline.

---

## 2. Creating the Apple files

### 2.1 Register the App ID

1. Go to <https://developer.apple.com/account/resources/identifiers/list>.
2. **+** → **App IDs** → **App**.
3. Description: `Strainwave`. Bundle ID: **Explicit** → `com.strainwave.app`.
   (If you change it, change `PRODUCT_BUNDLE_IDENTIFIER` in
   `ios/Strainwave/project.yml` and the `provisioningProfiles` key in the
   workflow's export options to match.)
4. Capabilities: leave everything off. The game needs none.

### 2.2 Create the distribution certificate

On a Mac:

1. Open **Keychain Access** → menu **Keychain Access → Certificate Assistant →
   Request a Certificate From a Certificate Authority**.
2. Enter your email and name, choose **Saved to disk**, and save
   `CertificateSigningRequest.certSigningRequest`.
3. Go to <https://developer.apple.com/account/resources/certificates/list> →
   **+** → **Apple Distribution** → upload the CSR → **Download** the `.cer`.
4. Double-click the `.cer` to install it into Keychain Access.
5. In Keychain Access, find **Apple Distribution: …**, expand it so the private
   key underneath is selected too, right-click → **Export 2 items…** →
   `Certificates.p12`. **Set a password** — that password becomes
   `IOS_DISTRIBUTION_CERT_PASSWORD`.
6. Base64 the `.p12` into `IOS_DISTRIBUTION_CERT_P12`.

> Without a Mac you cannot create the CSR yourself; the certificate has to be
> exported by someone on the team who has one.

### 2.3 Create the provisioning profile

1. <https://developer.apple.com/account/resources/profiles/list> → **+**.
2. **Distribution → App Store Connect** → Next.
3. App ID: `com.strainwave.app` → Next.
4. Certificate: the Apple Distribution certificate from § 2.2 → Next.
5. Name it something stable, e.g. `Strainwave App Store`. That exact string is
   `IOS_PROVISIONING_PROFILE_NAME`.
6. Download the `.mobileprovision`, base64 it into `IOS_PROVISIONING_PROFILE`.

### 2.4 Create the App Store Connect API key

1. <https://appstoreconnect.apple.com/access/integrations/api> → **Team Keys**.
2. **+**, name it `Strainwave CI`, access **App Manager**, → **Generate**.
3. Download `AuthKey_XXXXXXXXXX.p8`. **Apple lets you download it once.**
4. `APP_STORE_CONNECT_KEY_ID` is the ten-character Key ID in the table.
   `APP_STORE_CONNECT_ISSUER_ID` is the UUID shown above the table.
   `APP_STORE_CONNECT_PRIVATE_KEY` is the base64 of the `.p8`.

### 2.5 Create the app record

1. <https://appstoreconnect.apple.com/apps> → **+** → **New App**.
2. Platform iOS, Name `Strainwave`, Primary language English (U.S.),
   Bundle ID `com.strainwave.app`, SKU `strainwave-001`.
3. Fill the listing from [`APP_STORE_METADATA.md`](APP_STORE_METADATA.md).

---

## 3. Switching the ad SDK on

The app is written so that the ad layer is entirely optional: every AdMob file
is wrapped in `#if canImport(GoogleMobileAds)`, and the build works, tests pass,
and the game plays with the SDK absent. To switch it on:

1. In `ios/Strainwave/project.yml`, uncomment the `GoogleMobileAds` entries in
   both `packages:` and the app target's `dependencies:`.
2. Replace the three test unit IDs in
   `ios/Strainwave/Sources/Services/AdManager.swift` (`AdUnits`) with your real
   ones from <https://apps.admob.com>, and set `isUsingTestUnits = false`.
   `AdManagerTests.testTestUnitsAreStillFlagged` fails until you do — that is
   the reminder, not a bug.
3. Replace `GADApplicationIdentifier` in
   `ios/Strainwave/Sources/Resources/Info.plist` with your AdMob app ID.
4. Add the full `SKAdNetworkItems` list that AdMob publishes for the SDK version
   you linked; the plist currently carries only the first few entries.
5. Regenerate: `cd ios/Strainwave && xcodegen generate`.

**Never ship the test unit IDs.** Serving test ads to real users, or clicking
your own live ads while testing, is what gets AdMob accounts suspended.

---

## 4. First submission

```bash
# Locally, once, to confirm the project generates and builds:
brew install xcodegen
cd ios/Strainwave && xcodegen generate && open Strainwave.xcodeproj
```

Then in GitHub: **Actions → Strainwave iOS → Run workflow**. The `testflight`
job only runs on a manual dispatch, and only after the engine tests, the app
tests and the localisation check have passed.

When the build appears in App Store Connect:

1. **TestFlight → Manage** — answer the export-compliance question. The app uses
   no non-exempt encryption; `ITSAppUsesNonExemptEncryption` is already `false`
   in the plist, so this should not even be asked.
2. **App Privacy** — fill it in from
   [`APP_STORE_METADATA.md`](APP_STORE_METADATA.md#app-privacy-answers).
3. **Age rating** — the answers are in the same file.
4. Attach the build to the version, add the screenshots, and submit.

Work through [`PRE_SUBMISSION_CHECKLIST.md`](PRE_SUBMISSION_CHECKLIST.md) before
you press submit.
