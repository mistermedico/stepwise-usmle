# Secrets נדרשים

הרשימה המדויקת של GitHub Actions Secrets (Settings → Secrets and variables → Actions
→ New repository secret) שה-workflow ב-`.github/workflows/pathogen-protocol-ios.yml`
צורך. ה-job הראשון (`build-and-test`) **לא דורש שום secret** — הוא בונה ורץ על
סימולטור בלי חתימה. כל השאר נדרשים רק ל-job השני (`release`), שרץ רק כשמפעילים
אותו ידנית עם `upload_to_testflight: true`.

| שם ה-Secret | לאן הולך | איך משיגים |
|---|---|---|
| `APPLE_DEVELOPMENT_TEAM_ID` | `DEVELOPMENT_TEAM` בזמן archive/export | Apple Developer → Membership → Team ID (10 תווים) |
| `IOS_DIST_CERTIFICATE_BASE64` | ייבוא לקיצ'יין זמני ב-CI | ייצוא תעודת "Apple Distribution" מ-Keychain Access כ-`.p12`, ואז `base64 -i cert.p12 \| pbcopy` |
| `IOS_DIST_CERTIFICATE_PASSWORD` | סיסמת ה-`.p12` שבחרתם בזמן הייצוא | הסיסמה שהזנתם ב-Keychain Access בעת הייצוא |
| `IOS_PROVISIONING_PROFILE_BASE64` | פרופיל provisioning ל-App Store | הורדה מ-Apple Developer → Profiles, ואז `base64 -i profile.mobileprovision \| pbcopy` |
| `CI_KEYCHAIN_PASSWORD` | סיסמה זמנית לקיצ'יין ש-CI יוצר ומוחק בכל ריצה | כל מחרוזת אקראית חזקה — לא צריכה להיות זכורה בשום מקום אחר |
| `APP_STORE_CONNECT_KEY_ID` | Key ID של App Store Connect API Key | App Store Connect → Users and Access → Integrations → App Store Connect API |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID של אותו API Key | אותו מסך, למעלה |
| `APP_STORE_CONNECT_API_KEY_BASE64` | קובץ `AuthKey_XXXXX.p8` מקודד ב-base64 | לאחר יצירת המפתח: `base64 -i AuthKey_XXXXX.p8 \| pbcopy` — **שימו לב: הקובץ ניתן להורדה פעם אחת בלבד** |
| `ADMOB_APP_ID` | `GADApplicationIdentifier` ב-Info.plist דרך `project.yml` | AdMob console → App settings → App ID (פורמט `ca-app-pub-XXXXXXXX~YYYYYYYYYY`) |

## Ad Unit IDs (לא Secrets — Info.plist keys ב-Release)

אלה לא GitHub Secrets אלא ערכים שיש להזין ישירות ב-`project.yml` (או להעביר כ-build
setting אם מעדיפים לא לחשוף אותם ב-git — ad unit IDs אינם רגישים כמו API keys, אך
אם תרצו להסתיר אותם בכל זאת אפשר להעביר אותם כ-Secrets נוספים ולהזריק דרך `xcodebuild
-exportOptionsPlist`/`OTHER_SWIFT_FLAGS`):

- `AdMobInterstitialUnitID`
- `AdMobRewardedUnitID`
- `AdMobBannerUnitID`

עד אז, `AdUnitID.swift` נופל חזרה למחרוזת ריקה ב-Release אם המפתחות לא קיימים
ב-Info.plist — כלומר לא יקרוס, אבל גם לא יציג מודעות אמיתיות.

## מה **לא** לשים ב-git

- קובץ ה-`.p12`, ה-`.mobileprovision`, וה-`AuthKey_*.p8` עצמם — רק את הגרסה
  המקודדת ב-base64 כ-Secret.
- מפתחות AdMob אמיתיים בקובץ שנשמר לפוש (אם נכנסים כ-Info.plist properties ב-
  `project.yml`, הם ציבוריים ברגע שהריפו ציבורי — שקלו env var injection בזמן CI
  אם זה משנה לכם).
