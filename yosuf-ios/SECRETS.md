# GitHub Secrets — Exact List

Add these under **this repository → Settings → Secrets and variables → Actions → New repository secret**. Names must match exactly (case-sensitive). All 8 are required for `.github/workflows/yosuf-ios-release.yml` to run; nothing else needs a secret.

| # | Secret name | What it is | How you get it |
|---|---|---|---|
| 1 | `APPLE_TEAM_ID` | Your 10-character Apple Developer Team ID (e.g. `A1B2C3D4E5`) | Apple Developer → Membership page |
| 2 | `APP_STORE_CONNECT_API_KEY_ID` | The Key ID of an App Store Connect API key | App Store Connect → Users and Access → Integrations → App Store Connect API |
| 3 | `APP_STORE_CONNECT_API_ISSUER_ID` | The Issuer ID shown on the same API Keys page | Same page as above, top of the table |
| 4 | `APP_STORE_CONNECT_API_KEY_CONTENT` | The **base64-encoded contents** of the `.p8` private key file you downloaded when creating the API key | `base64 -i AuthKey_XXXXXXXXXX.p8 \| pbcopy` (see APPLE_SETUP.md step 3) |
| 5 | `IOS_DISTRIBUTION_CERTIFICATE_P12` | The **base64-encoded contents** of your Apple Distribution certificate, exported as a `.p12` file | Exported from Keychain Access (see APPLE_SETUP.md step 4) |
| 6 | `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD` | The password you chose when exporting the `.p12` file above | You make this up during export — write it down |
| 7 | `IOS_PROVISIONING_PROFILE_BASE64` | The **base64-encoded contents** of the App Store provisioning profile (`.mobileprovision`) for `com.yosufgame.app` | Downloaded from Apple Developer → Profiles (see APPLE_SETUP.md step 5) |
| 8 | `KEYCHAIN_PASSWORD` | Any password you make up — used only to protect a throwaway keychain created fresh on each CI run | Make up any strong string, e.g. from a password manager |

## How to base64-encode a file (macOS/Linux terminal)

```bash
base64 -i path/to/file.p8 | pbcopy      # macOS - copies straight to clipboard
base64 -w0 path/to/file.p8              # Linux - prints to terminal, then copy it
```

Paste the resulting single long line as the secret's value — do not add line breaks.

## Provisioning profile name

The Fastfile expects the provisioning profile's **name** (not its file name) in Apple Developer to be exactly:

```
Yosuf App Store Profile
```

If you name it differently, update the `PROFILE_NAME` constant at the top of `fastlane/Fastfile` to match.

## Nothing else requires a secret

- The AdMob **test** ad unit IDs in `AdManager.swift` and the test App ID in `project.yml` (`GADApplicationIdentifier`) work out of the box for development and CI builds — no AdMob account needed until you're ready to see real ads and revenue. Swapping them for your real IDs is a code edit, not a secret (see APPLE_SETUP.md step 6).
- The unit test workflow (`yosuf-ios-tests.yml`) needs zero secrets — it only builds and runs tests.
