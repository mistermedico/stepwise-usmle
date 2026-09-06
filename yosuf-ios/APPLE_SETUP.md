# Apple Developer Setup — The Only Steps That Need You

Everything else in this project is automated. These steps genuinely require a human with access to your Apple Developer account — Apple does not allow an automated tool to do them. Do them in order; each one produces a value used later.

You'll need: an active [Apple Developer Program](https://developer.apple.com/programs/) membership ($99/year), and access to [App Store Connect](https://appstoreconnect.apple.com) and the [Apple Developer portal](https://developer.apple.com/account).

---

## Step 1 — Register the App ID

1. Go to **developer.apple.com/account → Certificates, Identifiers & Profiles → Identifiers → +**.
2. Choose **App IDs → App**.
3. Description: `Yosuf`. Bundle ID: **Explicit** → `com.yosufgame.app` (must match exactly — this is hard-coded in `project.yml`).
4. Capabilities: leave everything unchecked (this app needs none).
5. Register.

## Step 2 — Create the app in App Store Connect

1. Go to **appstoreconnect.apple.com → Apps → +  → New App**.
2. Platform: iOS. Name: `Yosuf: Card Game`. Primary language: Hebrew.
3. Bundle ID: select `com.yosufgame.app` from Step 1.
4. SKU: anything unique, e.g. `yosuf-card-game-001`.
5. Create.

## Step 3 — Create an App Store Connect API key (for automated uploads)

1. **App Store Connect → Users and Access → Integrations → App Store Connect API**.
2. Click **+** to generate a new key. Name: `Yosuf CI`. Access: **App Manager**.
3. Download the `.p8` file **immediately** — Apple only lets you download it once.
4. Note the **Key ID** and **Issuer ID** shown on that page.
5. Base64-encode the `.p8` file (see `SECRETS.md` for the exact command) and save these three values:
   - `APP_STORE_CONNECT_API_KEY_ID`
   - `APP_STORE_CONNECT_API_ISSUER_ID`
   - `APP_STORE_CONNECT_API_KEY_CONTENT` (the base64 text)

## Step 4 — Create and export a Distribution Certificate

1. **developer.apple.com/account → Certificates → +**.
2. Choose **Apple Distribution**. Follow the prompts to generate a Certificate Signing Request (CSR) using **Keychain Access → Certificate Assistant → Request a Certificate from a Certificate Authority** on a Mac, upload it, and download the resulting certificate.
3. Double-click the downloaded certificate to install it into **Keychain Access** (login keychain).
4. In Keychain Access, find the certificate (under "My Certificates" — it will show a disclosure arrow with your private key nested under it), right-click it, choose **Export**, save as `.p12`, and set an export password (write it down — this becomes `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD`).
5. Base64-encode the `.p12` file → this becomes `IOS_DISTRIBUTION_CERTIFICATE_P12`.

## Step 5 — Create the App Store provisioning profile

1. **developer.apple.com/account → Profiles → +**.
2. Type: **App Store** (under Distribution).
3. App ID: `com.yosufgame.app`.
4. Certificate: the Distribution certificate from Step 4.
5. Name it **exactly** `Yosuf App Store Profile` (the automated build looks for this exact name — see `SECRETS.md`).
6. Generate and download the `.mobileprovision` file.
7. Base64-encode it → this becomes `IOS_PROVISIONING_PROFILE_BASE64`.

## Step 6 — Enter all 8 secrets in GitHub

Go to this repository → **Settings → Secrets and variables → Actions**, and add all 8 secrets exactly as named in `SECRETS.md`. Once they're in, go to **Actions** tab, select **"Yosuf iOS - Release to TestFlight"**, and click **Run workflow** to trigger your first automated build and TestFlight upload.

## Step 7 — (Optional, when you're ready to earn ad revenue) Set up real AdMob IDs

The app ships with Google's official **test** ad IDs so it builds and runs immediately with test ads. When you're ready for real ads:

1. Create an account at [admob.google.com](https://admob.google.com) and add the app (once it exists in App Store Connect from Step 2).
2. Create three ad units: one **Interstitial**, one **Rewarded**, one **Banner**.
3. In `yosuf-ios/YosufApp/Managers/AdManager.swift`, replace the three `AdUnitID` constants with your real unit IDs.
4. In `yosuf-ios/project.yml`, replace `GADApplicationIdentifier` with your real AdMob **App ID** (found in AdMob → App settings), then re-run `xcodegen generate` (CI does this automatically).
5. This is a plain code edit, not a secret — commit and push it like any other change.

## Step 8 — Fill in App Store Connect metadata

Copy-paste directly from `AppStoreMetadata/he-IL/` and `AppStoreMetadata/en-US/` into the **App Information** and **Version Information** pages in App Store Connect (name, subtitle, description, keywords, category, promotional text). No writing needed — it's ready to paste.

## Step 9 — Privacy policy URL

Publish the contents of `Legal/PrivacyPolicy_he.md` (and/or the English version) somewhere public — a GitHub Pages page, a simple hosted page, or any URL you control — and paste that URL into App Store Connect's **Privacy Policy URL** field. This is the one piece of "hosting" that's outside this repo's automation, since it needs a URL Apple can reach.

---

That's it. Every other step in the project — writing code, running tests, building, signing, and uploading — is automated by `.github/workflows/`.
