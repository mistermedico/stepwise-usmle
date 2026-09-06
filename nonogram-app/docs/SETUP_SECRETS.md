# השלמת ההגדרות ל-Picture Cross (חושף התמונה) / Finishing setup for Picture Cross

---

## חלק א: בעברית

### 1. מה כבר מוכן, ומה נשאר לך

כל הקוד של האפליקציה, כל מנגנון ה-CI/CD (הבנייה האוטומטית, הבדיקות האוטומטיות,
והצינור שמעלה גרסאות ל-TestFlight) — הכול כבר כתוב וקיים בריפו הזה, בתיקייה
`nonogram-app/`. אין צורך לכתוב עוד קוד כדי שהאפליקציה "תעבוד".

מה שנשאר הוא **רק** פעולות שדורשות חשבונות אישיים שלך (או של מי שאחראי על
הפרויקט מבחינה עסקית/משפטית):

- חשבון **Apple Developer** (כדי לחתום על האפליקציה ולהעלות אותה ל-App Store).
- חשבון **App Store Connect** (כדי ליצור את רשומת האפליקציה ולנהל TestFlight).
- חשבון **Google AdMob** (כדי להציג פרסומות באפליקציה).

אף אחד אחר לא יכול לעשות את השלבים האלה במקומך — הם דורשים בעלות על חשבונות
שרק אתה (או הארגון שלך) שולט בהם. זה החלק היחיד בכל הפרויקט שהוא **לא**
אוטומטי, וגם לא יכול להיות.

בסוף המדריך הזה תמצא/י גם טבלה מדויקת של כל ה"סודות" (secrets) שצריך להוסיף
ל-GitHub, בדיוק באותם שמות שהקוד כבר מצפה להם — כך שברגע שתמלא/י אותם, צינור
ה-CI פשוט יעבוד.

---

### 2. רשימת פעולות ב-Apple Developer Portal וב-App Store Connect (לפי סדר)

בצע/י את הפעולות האלה **בסדר הזה** — כל שלב תלוי בקודם לו.

1. **הרשמה ל-Apple Developer Program** (אם עוד לא נרשמת).
   זהו תנאי סף לכל השאר. העלות היא **99$ לשנה**. ההרשמה נעשית בכתובת
   developer.apple.com, עם Apple ID. אישור ההרשמה יכול לקחת מספר שעות עד יום.

2. **רישום ה-App ID (bundle identifier)**.
   ב-Apple Developer Portal: Certificates, Identifiers & Profiles > Identifiers
   > כפתור "+" > App IDs > App.
   המחרוזת שהקוד כבר מוגדר לצפות לה היא:
   ```
   com.nonogramstudio.picturecross
   ```
   **חשוב:** זו כרגע ערך זמני (placeholder) בקוד. אם אתה/את **לא** בעלים של
   המחרוזת הזו (למשל מישהו אחר כבר רשם אותה, או שאתה מעדיף/ה domain אחר
   שבבעלותך), בחר/י מחרוזת ייחודית משלך (למשל `com.<השם-שלך>.picturecross`)
   ותודיע/י כדי שנעדכן את `project.yml`, את `fastlane/Appfile` ואת כל מקום
   אחר שמזכיר את המחרוזת הזו בקוד.

3. **יצירת רשומת האפליקציה ב-App Store Connect**.
   בכתובת appstoreconnect.apple.com: My Apps > כפתור "+" > New App.
   בחר/י את ה-Bundle ID שרשמת בשלב 2, ותן/י לאפליקציה את השם:
   - אנגלית: **Picture Cross**
   - עברית: **חושף התמונה**
   **שימו לב:** שדה השם הזה הוא זה שבאמת "תופס" את השם ב-App Store, על בסיס
   כל הקודם זוכה (first-come-first-served) — אם מישהו אחר כבר רשם אפליקציה
   בשם "Picture Cross", תצטרכו לבחור שם אחר. לכן כדאי לעשות את הצעד הזה
   מוקדם ולא לדחות אותו.

4. **יצירת תעודת חתימה להפצה (Distribution Certificate) ופרופיל הרשאה
   (Provisioning Profile) מסוג App Store**.
   ב-Certificates, Identifiers & Profiles:
   - Certificates > "+" > בחר/י "Apple Distribution" > עקוב/י אחר ההוראות
     ליצירת CSR (Certificate Signing Request) דרך Keychain Access במחשב Mac,
     והעלה/י אותו. הורד/י את קובץ ה-`.cer` שנוצר ולחץ/י עליו פעמיים כדי
     שייכנס ל-Keychain Access שלך (זה שלב הכרחי לפני הייצוא ב-שלב 5).
   - Profiles > "+" > App Store > בחר/י את ה-App ID משלב 2 ואת התעודה
     שיצרת כרגע > הורד/י את קובץ ה-`.mobileprovision`.

5. **ייצוא התעודה כקובץ `.p12` מ-Keychain Access** (עם סיסמה שאתה/את בוחר/ת).
   ב-Mac, פתח/י את אפליקציית **Keychain Access**:
   - חפש/י את התעודה "Apple Distribution: <השם שלך> (<TEAM ID>)" שיצרת בשלב 4.
   - לחץ/י על החץ הקטן לידה כדי לראות את המפתח הפרטי (Private key) שמתחתיה.
   - בחר/י **גם** את התעודה **וגם** את המפתח הפרטי (Cmd+לחיצה כדי לבחור
     שניהם יחד).
   - קליק ימני > **Export 2 items…**.
   - שמור/י כקובץ מסוג **`.p12`**.
   - תתבקש/י להזין סיסמה להגנה על הקובץ — בחר/י סיסמה (זו הסיסמה שתישמר
     בסוד `IOS_DIST_CERTIFICATE_PASSWORD`, ראה/י טבלה למטה).

6. **יצירת App Store Connect API Key** (לצורך העלאה אוטומטית ל-TestFlight ללא
   צורך בהתחברות אישית / קוד אימות דו-שלבי בכל פעם).
   ב-App Store Connect: Users and Access > Integrations > App Store Connect
   API > **Generate API Key** (או "+").
   - תן/י שם למפתח, ובחר/י תפקיד (Role): **App Manager**.
   - **חשוב מאוד:** את קובץ ה-`.p8` ניתן להוריד **פעם אחת בלבד**. הורד/י
     אותו מיד ושמור/י אותו במקום בטוח (לדוגמה, מנהל סיסמאות). אם תאבד/י
     אותו, תצטרך/י ליצור מפתח חדש.
   - שים/י לב לשני ערכים שמופיעים באותו עמוד: **Key ID** ו-**Issuer ID**
     (ה-Issuer ID מופיע פעם אחת למעלה בעמוד ה-Integrations, משותף לכל
     המפתחות).

7. **מציאת ה-Team ID שלך**.
   ב-Apple Developer Portal: Membership (או Membership Details).
   ה-Team ID הוא מחרוזת של 10 תווים (אותיות ומספרים).

---

### 3. קידוד הקבצים הבינאריים ל-base64 (כדי להדביק אותם ב-GitHub)

GitHub Secrets מקבל רק טקסט, ולכן קבצים בינאריים (`.p12`, `.mobileprovision`,
`.p8`) צריך לקודד תחילה ל-base64 (מחרוזת טקסט ארוכה) — ורק אותה מדביקים.

**ב-Mac** (מעתיק ישירות ל-clipboard):
```bash
base64 -i Certificates.p12 | pbcopy
base64 -i profile.mobileprovision | pbcopy
base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
```
(הרץ/י פעם אחת בכל פעם, והדבק/י ישר בשדה הסוד המתאים ב-GitHub לפני שמריצים
את הפקודה הבאה — כי כל פקודה דורסת את מה שהיה ב-clipboard.)

**בלינוקס** (עם `xclip`, אם מותקן):
```bash
base64 -w0 Certificates.p12 | xclip -selection clipboard
base64 -w0 profile.mobileprovision | xclip -selection clipboard
base64 -w0 AuthKey_XXXXXXXXXX.p8 | xclip -selection clipboard
```
אם אין `xclip`, אפשר גם פשוט:
```bash
base64 -w0 Certificates.p12 > cert_base64.txt
```
ולפתוח את `cert_base64.txt` בעורך טקסט ולהעתיק את כל התוכן משם.

---

### 4. טבלת כל הסודות (Secrets) שצריך להוסיף ב-GitHub

הוספה נעשית ב: הריפו `mistermedico/stepwise-usmle` ב-GitHub > **Settings**
> **Secrets and variables** > **Actions** > **New repository secret**.
עבור כל שורה בטבלה: הדבק/י את השם המדויק (עמודה שמאלית) ואת הערך המתאים.

| שם הסוד (חייב להיות מדויק) | מה שמים בו |
|---|---|
| `IOS_DIST_CERTIFICATE_BASE64` | תוכן ה-base64 של קובץ ה-`.p12` (שלב 5). |
| `IOS_DIST_CERTIFICATE_PASSWORD` | הסיסמה שבחרת בשלב 5 בזמן ייצוא ה-`.p12`. |
| `IOS_PROVISIONING_PROFILE_BASE64` | תוכן ה-base64 של קובץ ה-`.mobileprovision` (שלב 4). |
| `IOS_KEYCHAIN_PASSWORD` | **לא** קשור לשום חשבון אמיתי — זו סיסמה זמנית, מומצאת, ששרת ה-CI משתמש בה כדי לנעול/לפתוח keychain זמני שהוא יוצר לעצמו בזמן הריצה בלבד. אפשר להמציא כל מחרוזת אקראית (למשל דרך `openssl rand -base64 24`). |
| `APPLE_TEAM_ID` | ה-Team ID מ-Membership (שלב 7). |
| `APP_STORE_CONNECT_API_KEY_ID` | ה-Key ID מעמוד יצירת ה-API Key (שלב 6). |
| `APP_STORE_CONNECT_API_ISSUER_ID` | ה-Issuer ID מאותו עמוד (שלב 6). |
| `APP_STORE_CONNECT_API_KEY_BASE64` | תוכן ה-base64 של קובץ ה-`.p8` שהורדת (שלב 6). |

שמות אלה מופיעים **בדיוק** ככה גם בקובץ ה-workflow
(`.github/workflows/nonogram-ios.yml`) וגם ב-`fastlane/Fastfile` — אין צורך
לשנות שום קובץ קוד, רק להוסיף את הסודות האלה ב-GitHub.

---

### 5. הגדרת AdMob (חשבון נפרד, google.com/admob)

1. היכנס/י ל-google.com/admob וצור/י (או השתמש/י ב) חשבון Google.
2. Apps > **Add app** > צור/י רשומת אפליקציה עבור Picture Cross (iOS).
3. תקבל/י **App ID** בפורמט `ca-app-pub-XXXXXXXX~YYYYYYYY` — שמור/י אותו.
4. תחת אותה אפליקציה, צור/י שלוש יחידות מודעה (Ad units): אחת מסוג
   **Interstitial**, אחת מסוג **Rewarded**, ואחת מסוג **Banner**. לכל אחת
   תקבל/י מזהה בפורמט `ca-app-pub-XXXXXXXX/ZZZZZZZZZZ`.
5. הכנסת הערכים לקוד:
   - ה-App ID (עם ה-`~`) צריך להיכנס למפתח `GADApplicationIdentifier` בקובץ
     ה-Info.plist של האפליקציה.
   - מזהי יחידות המודעה (עם ה-`/`) צריכים להחליף כל TODO רלוונטי בקובץ
     האחראי על ניהול המודעות (למשל `AdManager.swift`, אם קיים בשלב שבו
     תגיע/י לצעד הזה). **אם קובץ כזה עדיין לא קיים** בזמן שאת/ה מבצע/ת את
     השלב הזה — חפש/י בכל הפרויקט (`nonogram-app/`) הערות מסוג
     `// TODO: replace with production ad unit ID` (או דומה) ותחליף/י שם.
   - שים/י לב: עד שיוכנסו מזהי מודעה אמיתיים, מומלץ להשתמש במזהי הבדיקה
     הרשמיים של Google (מתועדים באתר AdMob) כדי לא להפר את מדיניות Google
     בזמן פיתוח.

---

### 6. איך בפועל מפעילים שחרור (release) ל-TestFlight

לאחר שכל הסודות בטבלה שבסעיף 4 מוגדרים ב-GitHub, יש שתי דרכים להפעיל את
תהליך השחרור:

- **תיוג גרסה (מומלץ לשחרורים רשמיים):** צור/י והדוף/י (push) תג git בפורמט
  `nonogram-v1.0.0`:
  ```bash
  git tag nonogram-v1.0.0
  git push origin nonogram-v1.0.0
  ```
- **הפעלה ידנית:** בכרטיסייה **Actions** ב-GitHub, בחר/י את ה-workflow
  "Nonogram iOS", ולחץ/י על **Run workflow**.

מה לצפות: תוך כ-**15–30 דקות** אמורה להופיע גרסה חדשה (build) ב-App Store
Connect, תחת TestFlight. משם, עדיין תצטרכו לבצע ידנית (זה שלב שרק אתם יכולים
לעשות, כי הוא כרוך באחריות משפטית/עסקית שלכם על מה שמפורסם):
- להוסיף את הבילד לקבוצת TestFlight כדי שבודקים יוכלו להתקין אותו, ו/או
- ללחוץ בפועל על **Submit for Review** כדי לשלוח את הגרסה ל-App Review של
  Apple, כשתהיו מוכנים לפרסום ציבורי.

---
---

## Part B: English

### 1. What's already done, and what's left for you

All of the app's code, and the entire CI/CD pipeline (automatic building,
automatic testing, and the pipeline that uploads new builds to TestFlight)
already exists in this repo, under `nonogram-app/`. No further code needs to
be written to make the app "work."

What's left is **only** work that requires personal accounts belonging to you
(or whoever is responsible for the project's business/legal side):

- An **Apple Developer** account (to sign the app and submit it to the App
  Store).
- An **App Store Connect** account (to create the app record and manage
  TestFlight).
- A **Google AdMob** account (to show ads in the app).

Nobody else can complete these steps on your behalf — they require ownership
of accounts that only you (or your organization) control. This is the one
part of the whole project that is **not** automated, and structurally can't
be.

At the end of this guide you'll also find an exact table of every "secret"
that needs to be added to GitHub, using the exact same names the code
already expects — once you fill those in, the CI pipeline will simply work.

---

### 2. Checklist of actions in the Apple Developer Portal / App Store Connect (in order)

Do these **in this order** — each step depends on the one before it.

1. **Enroll in the Apple Developer Program** (if you haven't already).
   This is a prerequisite for everything else. It costs **$99/year**. Enroll
   at developer.apple.com with an Apple ID. Approval can take anywhere from a
   few hours to about a day.

2. **Register the App ID (bundle identifier).**
   In the Apple Developer Portal: Certificates, Identifiers & Profiles >
   Identifiers > "+" > App IDs > App.
   The exact string the code currently expects is:
   ```
   com.nonogramstudio.picturecross
   ```
   **Important:** this is currently a placeholder in the code. If you do
   **not** own this exact string (e.g. someone else already registered it,
   or you'd rather use a domain you actually own), pick your own unique
   string instead (e.g. `com.<your-name>.picturecross`) and let us know so
   `project.yml`, `fastlane/Appfile`, and every other place in the code that
   references it can be updated to match.

3. **Create the app record in App Store Connect.**
   At appstoreconnect.apple.com: My Apps > "+" > New App.
   Select the Bundle ID from step 2, and name the app:
   - English: **Picture Cross**
   - Hebrew: **חושף התמונה**
   **Note:** this name field is what actually reserves the name on the App
   Store, on a first-come-first-served basis — if someone else has already
   registered an app called "Picture Cross," you'll have to pick a different
   name. Do this step promptly rather than putting it off.

4. **Create a Distribution Certificate and a Provisioning Profile (App Store
   distribution type)** for that bundle ID.
   In Certificates, Identifiers & Profiles:
   - Certificates > "+" > choose "Apple Distribution" > follow the
     instructions to generate a CSR (Certificate Signing Request) via
     Keychain Access on a Mac, and upload it. Download the resulting `.cer`
     file and double-click it so it's installed into your Keychain Access
     (this is required before you can export it in step 5).
   - Profiles > "+" > App Store > select the App ID from step 2 and the
     certificate you just created > download the `.mobileprovision` file.

5. **Export the certificate as a `.p12` file from Keychain Access** (with a
   password of your choosing).
   On a Mac, open the **Keychain Access** app:
   - Find the "Apple Distribution: <your name> (<TEAM ID>)" certificate you
     created in step 4.
   - Click the small disclosure arrow next to it to reveal its private key
     underneath.
   - Select **both** the certificate **and** its private key (Cmd-click to
     select both at once).
   - Right-click > **Export 2 items…**.
   - Save it as a **`.p12`** file.
   - You'll be asked to set a password protecting the file — choose one (this
     is the password that goes into the `IOS_DIST_CERTIFICATE_PASSWORD`
     secret; see the table below).

6. **Create an App Store Connect API Key** (so uploading to TestFlight can be
   fully automated, without needing anyone's personal sign-in or two-factor
   code each time).
   In App Store Connect: Users and Access > Integrations > App Store
   Connect API > **Generate API Key** (or "+").
   - Name the key, and set its Role to: **App Manager**.
   - **Very important:** the `.p8` key file can only be downloaded **once**.
     Download it immediately and store it somewhere safe (e.g. a password
     manager). If you lose it, you'll have to generate a new key.
   - Note two values shown on that page: the **Key ID** and the **Issuer ID**
     (the Issuer ID is shown once near the top of the Integrations page and
     is shared across all keys).

7. **Find your Team ID.**
   In the Apple Developer Portal: Membership (or Membership Details) page.
   The Team ID is a 10-character alphanumeric string.

---

### 3. Exact commands to base64-encode each binary secret

GitHub Secrets only accepts text, so binary files (`.p12`, `.mobileprovision`,
`.p8`) need to be base64-encoded into a long text string first — that's what
actually gets pasted in.

**On macOS** (copies straight to the clipboard):
```bash
base64 -i Certificates.p12 | pbcopy
base64 -i profile.mobileprovision | pbcopy
base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
```
(Run one at a time, and paste each into its GitHub secret field before
running the next command — each command overwrites whatever was on the
clipboard.)

**On Linux** (with `xclip`, if installed):
```bash
base64 -w0 Certificates.p12 | xclip -selection clipboard
base64 -w0 profile.mobileprovision | xclip -selection clipboard
base64 -w0 AuthKey_XXXXXXXXXX.p8 | xclip -selection clipboard
```
If `xclip` isn't available, you can also just do:
```bash
base64 -w0 Certificates.p12 > cert_base64.txt
```
and open `cert_base64.txt` in a text editor to copy the contents from there.

---

### 4. Table of every GitHub Actions secret to add

Add these at: the `mistermedico/stepwise-usmle` repo on GitHub >
**Settings** > **Secrets and variables** > **Actions** > **New repository
secret**. For each row below, paste the exact name (left column) and the
matching value.

| Secret name (must match exactly) | What goes in it |
|---|---|
| `IOS_DIST_CERTIFICATE_BASE64` | The base64 content of the `.p12` file (step 5). |
| `IOS_DIST_CERTIFICATE_PASSWORD` | The password you chose in step 5 when exporting the `.p12`. |
| `IOS_PROVISIONING_PROFILE_BASE64` | The base64 content of the `.mobileprovision` file (step 4). |
| `IOS_KEYCHAIN_PASSWORD` | **Not** tied to any real account — this is just a throwaway password the CI workflow uses to lock/unlock a temporary keychain it creates for itself during the run. Make up any random string (e.g. via `openssl rand -base64 24`). |
| `APPLE_TEAM_ID` | The Team ID from the Membership page (step 7). |
| `APP_STORE_CONNECT_API_KEY_ID` | The Key ID from the API key creation page (step 6). |
| `APP_STORE_CONNECT_API_ISSUER_ID` | The Issuer ID from that same page (step 6). |
| `APP_STORE_CONNECT_API_KEY_BASE64` | The base64 content of the `.p8` file you downloaded (step 6). |

These names appear **exactly** like this in both the workflow file
(`.github/workflows/nonogram-ios.yml`) and `fastlane/Fastfile` — there's no
need to change any code file, just add these secrets on GitHub.

---

### 5. AdMob setup (a separate account, at google.com/admob)

1. Go to google.com/admob and sign in with (or create) a Google account.
2. Apps > **Add app** > create an app entry for Picture Cross (iOS).
3. You'll get an **App ID** in the format `ca-app-pub-XXXXXXXX~YYYYYYYY` —
   save it.
4. Under that app, create three ad units: one **Interstitial**, one
   **Rewarded**, and one **Banner**. Each gets an ID in the format
   `ca-app-pub-XXXXXXXX/ZZZZZZZZZZ`.
5. Where these values go in the project:
   - The App ID (the one with `~`) goes into the `GADApplicationIdentifier`
     key in the app's Info.plist.
   - The ad unit IDs (the ones with `/`) replace whichever TODO markers exist
     in the file responsible for ad management (e.g. `AdManager.swift`, if
     it exists by the time you reach this step). **If that file doesn't
     exist yet** when you do this — search the whole project
     (`nonogram-app/`) for comments like
     `// TODO: replace with production ad unit ID` and replace them there.
   - Note: until real ad unit IDs are in place, use Google's official test ad
     unit IDs (documented on the AdMob site) so development doesn't violate
     Google's policies.

---

### 6. How to actually trigger a release to TestFlight

Once every secret in the table in section 4 is set on GitHub, there are two
ways to kick off a release:

- **Push a version tag (recommended for official releases):** create and
  push a git tag matching `nonogram-v1.0.0`:
  ```bash
  git tag nonogram-v1.0.0
  git push origin nonogram-v1.0.0
  ```
- **Trigger it manually:** on GitHub, go to the **Actions** tab, select the
  "Nonogram iOS" workflow, and click **Run workflow**.

What to expect: within roughly **15–30 minutes**, a new build should appear
in App Store Connect under TestFlight. From there, you still need to
manually (this step can only be done by you, since it carries your own
legal/business responsibility for what gets published):
- Add the build to a TestFlight group so testers can install it, and/or
- Actually click **Submit for Review** to send the build to Apple's App
  Review, once you're ready for it to go public.
