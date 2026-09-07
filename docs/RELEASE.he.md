# שחרור Strainwave — מדריך בעברית

זו גרסה עברית של [`RELEASE.md`](RELEASE.md), מסודרת כרצף פעולות. כל השאר
בפרויקט אוטומטי; מה שכאן דורש אותך ואת חשבון ה‑Apple Developer שלך.

**סדר העבודה:** חלק א' → ב' → ג' → ד' → ה' → ו'. חלקים א'–ב' הם חד־פעמיים.

---

## חלק א' — הקבצים אצל Apple (חד־פעמי)

### א.1 — רישום מזהה האפליקציה

1. היכנס ל־<https://developer.apple.com/account/resources/identifiers/list>
2. **+** ← **App IDs** ← **App**
3. Description: `Strainwave`. Bundle ID: **Explicit** ← `com.strainwave.app`
4. אל תסמן שום Capability. המשחק לא צריך אף אחת מהן.

> אם תשנה את ה‑Bundle ID, עדכן גם את `PRODUCT_BUNDLE_IDENTIFIER` בקובץ
> `ios/Strainwave/project.yml` וגם את המפתח `provisioningProfiles` בקובץ
> `.github/workflows/ios.yml`.

### א.2 — תעודת ההפצה

**דורש Mac.** אם אין לך, מישהו בצוות עם Mac צריך לבצע את השלב הזה ולייצא לך
את הקובץ.

1. פתח **Keychain Access** ← תפריט **Keychain Access → Certificate Assistant
   → Request a Certificate From a Certificate Authority**
2. מלא אימייל ושם, בחר **Saved to disk**, ושמור את
   `CertificateSigningRequest.certSigningRequest`
3. <https://developer.apple.com/account/resources/certificates/list> ← **+** ←
   **Apple Distribution** ← העלה את קובץ ה‑CSR ← **Download** של קובץ ה‑`.cer`
4. לחיצה כפולה על ה‑`.cer` כדי להתקין אותו ב‑Keychain
5. ב‑Keychain, אתר את **Apple Distribution: …**, פתח את המשולש כך שגם המפתח
   הפרטי שמתחתיו נבחר, לחיצה ימנית ← **Export 2 items…** ← שמור כ‑
   `Certificates.p12`
6. **הגדר סיסמה בייצוא.** הסיסמה הזו היא הערך של
   `IOS_DISTRIBUTION_CERT_PASSWORD`

### א.3 — פרופיל ההקצאה

1. <https://developer.apple.com/account/resources/profiles/list> ← **+**
2. **Distribution → App Store Connect** ← Next
3. App ID: `com.strainwave.app` ← Next
4. Certificate: התעודה מ‑א.2 ← Next
5. תן שם יציב, למשל `Strainwave App Store`. **המחרוזת המדויקת הזו** היא הערך
   של `IOS_PROVISIONING_PROFILE_NAME`
6. הורד את קובץ ה‑`.mobileprovision`

### א.4 — מפתח ה‑API של App Store Connect

1. <https://appstoreconnect.apple.com/access/integrations/api> ← לשונית
   **Team Keys**
2. **+**, שם: `Strainwave CI`, הרשאה: **App Manager** ← **Generate**
3. הורד את `AuthKey_XXXXXXXXXX.p8`.
   **Apple מאפשרת הורדה אחת בלבד — שמור אותו במקום בטוח.**
4. ה‑Key ID (עשרה תווים) הוא `APP_STORE_CONNECT_KEY_ID`.
   ה‑Issuer ID (UUID מעל הטבלה) הוא `APP_STORE_CONNECT_ISSUER_ID`.

### א.5 — יצירת רשומת האפליקציה

1. <https://appstoreconnect.apple.com/apps> ← **+** ← **New App**
2. Platform: iOS, Name: `Strainwave`, Primary language: English (U.S.),
   Bundle ID: `com.strainwave.app`, SKU: `strainwave-001`
3. מלא את הליסטינג מתוך [`APP_STORE_METADATA.md`](APP_STORE_METADATA.md)

---

## חלק ב' — הזנת ה‑secrets ל‑GitHub

ב‑GitHub: **Settings → Secrets and variables → Actions**, בסביבה בשם
**`release`** (המשימה `testflight` מוגבלת אליה).

| שם ה‑secret | מה זה | מאיפה |
| --- | --- | --- |
| `APPLE_TEAM_ID` | Team ID בן עשרה תווים | developer.apple.com ← Membership |
| `IOS_DISTRIBUTION_CERT_P12` | base64 של קובץ ה‑`.p12` | א.2 |
| `IOS_DISTRIBUTION_CERT_PASSWORD` | הסיסמה שהגדרת בייצוא | א.2 שלב 6 |
| `IOS_PROVISIONING_PROFILE` | base64 של ה‑`.mobileprovision` | א.3 |
| `IOS_PROVISIONING_PROFILE_NAME` | **שם** הפרופיל בדיוק כפי שנתת לו | א.3 שלב 5 |
| `KEYCHAIN_PASSWORD` | מחרוזת אקראית כלשהי | `openssl rand -base64 24` |
| `APP_STORE_CONNECT_KEY_ID` | Key ID בן עשרה תווים | א.4 |
| `APP_STORE_CONNECT_ISSUER_ID` | ה‑UUID של המנפיק | א.4 |
| `APP_STORE_CONNECT_PRIVATE_KEY` | base64 של קובץ ה‑`.p8` | א.4 |

להמרת קובץ ל‑base64:

```bash
base64 -i Certificates.p12 | pbcopy      # macOS — מעתיק ללוח
base64 -w0 Certificates.p12              # Linux
```

הדבק את התוצאה כערך ה‑secret — **בלי שורות חדשות ובלי רווח בסוף.**

---

## חלק ג' — הפעלת AdMob

היום המשחק מקומפל **בלי** ה‑SDK: כל קובץ פרסום עטוף ב‑
`#if canImport(GoogleMobileAds)`, ולכן הפרויקט נבנה, הבדיקות עוברות והמשחק
משוחק גם בלעדיו — משבצות הפרסום פשוט לא עושות כלום. להפעלה:

**ג.1** בקובץ `ios/Strainwave/project.yml`, בטל את ההערה משתי הפסקאות של
`GoogleMobileAds` — גם ב‑`packages:` וגם ב‑`dependencies:` של מטרת האפליקציה.

**ג.2** ב‑`ios/Strainwave/Sources/Services/AdManager.swift`, ב‑`enum AdUnits`
(שורות 48–57): החלף את שלושת מזהי היחידות במזהים האמיתיים שלך מ‑
<https://apps.admob.com>, ושנה `isUsingTestUnits` ל‑`false`.

> הבדיקה `AdManagerTests.testTestUnitsAreStillFlagged` **תיכשל בכוונה** עד
> שתעשה את זה. זו התזכורת, לא באג.

**ג.3** ב‑`ios/Strainwave/Sources/Resources/Info.plist`, החלף את הערך של
`GADApplicationIdentifier` במזהה האפליקציה שלך ב‑AdMob.

**ג.4** הוסף את רשימת `SKAdNetworkItems` המלאה ש‑AdMob מפרסמת לגרסת ה‑SDK
שקישרת. בקובץ יש כרגע שלוש רשומות בלבד.

**ג.5** צור מחדש את הפרויקט:

```bash
cd ios/Strainwave && xcodegen generate
```

> ⚠️ **לעולם אל תשחרר עם מזהי הבדיקה.** הגשת פרסומות בדיקה למשתמשים
> אמיתיים — או לחיצה על הפרסומות החיות שלך בזמן בדיקה — היא הדרך הבטוחה
> להשעיית חשבון AdMob.

---

## חלק ד' — בנייה והעלאה ל‑TestFlight

**ד.1 — פעם אחת, מקומית, לוודא שהפרויקט נוצר ונבנה:**

```bash
brew install xcodegen
cd ios/Strainwave && xcodegen generate && open Strainwave.xcodeproj
```

**ד.2 — הרצת ההעלאה:** ב‑GitHub ← **Actions → Strainwave iOS → Run
workflow**. משימת ה‑`testflight` רצה רק בהפעלה ידנית, ורק אחרי שבדיקות
המנוע, בדיקות האפליקציה ובדיקת הלוקליזציה עברו.

**ד.3 — כשהבנייה מופיעה ב‑App Store Connect:**

1. **TestFlight → Manage** — שאלת תאימות הייצוא. המשחק לא משתמש בהצפנה
   שאינה פטורה, והמפתח `ITSAppUsesNonExemptEncryption` כבר מוגדר `false`
   ב‑plist, כך שהשאלה בדרך כלל לא תישאל בכלל.
2. **App Privacy** — מלא מתוך
   [`APP_STORE_METADATA.md`](APP_STORE_METADATA.md#app-privacy-answers)
3. **Age rating** — התשובות באותו קובץ

---

## חלק ה' — הבדיקות שדורשות מכשיר אמיתי

ה‑CI מריץ בדיקות ממשק על סימולטור, אבל שלושה דברים אי אפשר לאמת שם. עשה
אותם על מכשיר, על בנייה מ‑TestFlight.

### ה.1 — VoiceOver בעין

**הפעלה:** הגדרות ← נגישות ← VoiceOver.
כדאי גם: נגישות ← קיצור דרך נגישות ← VoiceOver, ואז לחיצה משולשת על כפתור
הצד מדליקה ומכבה.

**מה לבדוק:**
- החלק ימינה על הלוח: כל אחד מ‑12 האזורים מכריז את שמו ואת מצבו
  (אחוז הדבקה, סגר, אזהרה). ה‑CI מוודא שהם *קיימים* ומכריזים משהו — אתה
  מוודא שזה **נקרא טוב ובסדר הגיוני**.
- במפת היכולות: כל צומת מכריז את שמו ואת עלותו.
- לוח הבקרה: הכפתור הראשי, בורר הרמה ובורר עולם ההתחלה מכריזים מה נבחר.

### ה.2 — עברית ו‑RTL בפועל

**הפעלה:** הגדרות ← כללי ← שפה ואזור ← עברית.

**מה לבדוק במיוחד** (המקומות שבהם RTL נשבר בדרך כלל):
- לוח הבקרה — הכיוון של השורות והכפתורים
- מפת היכולות — הענפים, הקווים והפאנל התחתון
- ציר הזמן בדוח המגיפה — הנקודות והקו המחבר צריכים להיות בצד הנכון
- מוני המספרים — הספרות עצמן נשארות LTR, וזה נכון

**טיפ למפתחים:** ב‑Xcode אפשר לבדוק בלי לשנות את שפת המכשיר —
Product → Scheme → Edit Scheme → Run → Options →
**Application Language: Hebrew**, ולבדיקת קצה
**Right‑to‑Left Pseudolanguage**.

### ה.3 — גודל טקסט ותנועה

- הגדרות ← נגישות ← תצוגה וגודל טקסט ← **טקסט גדול יותר** ← גרור לקצה.
  עבור על כל מסך: שום דבר לא נחתך, שום דבר לא חופף, וכפתור "התחל התפרצות"
  ו"יכולות" נשארים בהישג יד.
- הגדרות ← נגישות ← תנועה ← **הפחת תנועה**: הלוח מפסיק לנשום, הדוח מופיע
  בבת אחת, ושום דבר לא נשאר בלתי נראה באמצע אנימציה.

### ה.4 — פרסום והסכמה

- בקשת המעקב (ATT) מופיעה פעם אחת בהפעלה ראשונה, ולא שוב.
- סירוב לבקשה משאיר את המשחק שחיק במלואו.
- **הגדרות → העדפות פרסום** בתוך המשחק פותח את טופס ההסכמה באזור האירופי
  (לבדיקה: VPN, או שינוי גיאוגרפיה ב‑Xcode).
- לאיפוס הבקשה לבדיקה חוזרת: הגדרות iOS ← פרטיות ואבטחה ← מעקב.

### ה.5 — התקנה נקייה

**זה השלב שהכי מועד להישבר והכי פחות נבדק.**

1. מחק את האפליקציה מהמכשיר לגמרי
2. התקן מחדש מ‑TestFlight
3. הפעל: בקשת ההסכמה מופיעה, גלריית הדוחות מציגה את מצב הריקנות המעוצב
   ("המדף ריק"), והאתגר היומי נטען
4. שחק ריצה שלמה עד ניצחון ועוד אחת עד הפסד
5. שחק אתגר יומי עד הסוף, וודא שהדוח מתויק ושהאתגר מסומן כהושלם
6. העבר את האפליקציה לרקע באמצע ריצה וחזור: השעון נעצר, ושום דבר לא נספר
   פעמיים

---

## חלק ו' — הגשה

עבור על [`PRE_SUBMISSION_CHECKLIST.md`](PRE_SUBMISSION_CHECKLIST.md) לפני
הלחיצה על Submit. ודא במיוחד:

- כתובת מדיניות הפרטיות חיה ומגיבה בדפדפן, ותואמת לכתובת שב‑
  `SettingsView.privacyURL`
- צילומי מסך ל‑6.7 ול‑6.5 אינץ', בשתי השפות
- הערות לצוות הבדיקה, מועתקות מ‑`APP_STORE_METADATA.md`
- מספרי הגרסה והבנייה עודכנו (`MARKETING_VERSION`,
  `CURRENT_PROJECT_VERSION` ב‑`project.yml`)
