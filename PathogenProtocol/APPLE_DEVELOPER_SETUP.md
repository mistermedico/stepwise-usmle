# הדרכה: יצירת קבצי Apple Developer

מדריך פשוט, צעד-צעד, ליצירת כל מה שצריך כדי לחתום ולהעלות בילד ל-TestFlight/App
Store. מניח שיש לכם כבר חשבון Apple Developer Program פעיל (99$/שנה).

## 1. Team ID

Apple Developer → Account → Membership Details → **Team ID** (10 תווים, לדוגמה
`AB12CD34EF`). זה הערך של `APPLE_DEVELOPMENT_TEAM_ID`.

## 2. App ID (Bundle Identifier)

Apple Developer → Certificates, Identifiers & Profiles → Identifiers → **+** →
App IDs → App → הזינו `com.pathogenprotocol.app` (או ה-Bundle ID שבחרתם ב-
`project.yml`) → סמנו Capabilities רלוונטיים (ברירת המחדל מספיקה למשחק הזה,
אין Push/HealthKit וכו') → Register.

## 3. תעודת חתימה (Distribution Certificate)

1. פתחו Keychain Access במק במחשב שלכם.
2. Certificate Assistant → Request a Certificate From a Certificate Authority →
   מלאו את המייל שלכם, בחרו "Saved to disk" → שמרו את קובץ ה-`.certSigningRequest`.
3. Apple Developer → Certificates → **+** → Apple Distribution → העלו את קובץ
   ה-CSR → הורידו את התעודה (`.cer`) → פתחו אותה (תיכנס אוטומטית ל-Keychain).
4. ב-Keychain Access, מצאו את התעודה תחת "My Certificates", לחצו ימני → Export →
   שמרו כ-`.p12`, בחרו סיסמה (זה `IOS_DIST_CERTIFICATE_PASSWORD`).
5. `base64 -i DistCert.p12 | pbcopy` → הדביקו כ-`IOS_DIST_CERTIFICATE_BASE64`.

## 4. Provisioning Profile

Apple Developer → Profiles → **+** → App Store → בחרו את ה-App ID מסעיף 2 →
בחרו את התעודה מסעיף 3 → תנו שם → Generate → Download.

`base64 -i profile.mobileprovision | pbcopy` → `IOS_PROVISIONING_PROFILE_BASE64`.

## 5. App Store Connect API Key

App Store Connect → Users and Access → Integrations (טאב עליון) → App Store
Connect API → **+** (Generate API Key) → תפקיד **App Manager** מספיק להעלאת
בילדים → Generate.

- `Key ID` → `APP_STORE_CONNECT_KEY_ID`
- `Issuer ID` (למעלה בעמוד) → `APP_STORE_CONNECT_ISSUER_ID`
- לחצו Download API Key **מיד** — ניתן להוריד רק פעם אחת! שמרו את הקובץ
  `AuthKey_XXXXXXXXXX.p8` במקום בטוח, ואז:
  `base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy` → `APP_STORE_CONNECT_API_KEY_BASE64`

## 6. יצירת האפליקציה ב-App Store Connect

App Store Connect → My Apps → **+** → New App → iOS → מלאו Bundle ID (מהרשימה
שכבר קיימת מסעיף 2), שם, שפה ראשית. כאן גם תדביקו בהמשך את התוכן מ-
`APP_STORE_METADATA.md`.

## 7. AdMob App ID

[admob.google.com](https://admob.google.com) → Apps → Add App → iOS → קשרו
לאפליקציה שיצרתם ב-App Store Connect (או "not linked yet" בשלב פיתוח) → העתיקו
את ה-App ID (`ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`) → `ADMOB_APP_ID`. תחת
Ad units, צרו Interstitial + Rewarded + Banner ל"Ad Unit IDs" (ר' SECRETS.md).

## 8. הזנת ה-Secrets ל-GitHub

GitHub repo → Settings → Secrets and variables → Actions → New repository secret,
עבור כל שורה בטבלה ב-[`SECRETS.md`](SECRETS.md).

לאחר מכן: Actions טאב → Pathogen Protocol iOS → Run workflow → סמנו
`upload_to_testflight`.
