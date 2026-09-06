# Pathogen Protocol

משחק אסטרטגיה/סימולציה בדיוני לחלוטין ל-iOS: שולטים בפתוגן פיקטיבי, משדרגים אותו
דרך עץ יכולות בשלושה ענפים, ומנסים להדביק עולם מופשט לפני שה"מערכת תגובה עולמית"
מבוססת-חוקים (לא AI) מפתחת תרופה. ראו את הפרומפט המקורי לפרטי הקונספט המלא.

## שם ומיתוג

נבחר **Pathogen Protocol** מתוך ארבע הצעות:

1. **Pathogen Protocol** (נבחר) — שתי מילות מפתח חזקות ל-ASO ("pathogen" ו-"protocol"
   שתיהן נפוצות בחיפושי משחקי אסטרטגיה), קלות להגייה בשתי השפות, ולא מתנגשות עם
   מותג קיים.
2. Contagion Lab — "Contagion" עלול להתנגש אסוציאטיבית עם סרט קיים בשם זה.
3. Strain: Outbreak Tactics — ארוך מדי לכותרת אפליקציה (ASO מעדיף שם קצר).
4. Spread Theory — פחות ברור מיידית שמדובר במשחק אסטרטגיה.

Bundle ID: `com.pathogenprotocol.app`

## ארכיטקטורה

```
PathogenProtocol/
  project.yml                  ← מפרט XcodeGen; מריץ `xcodegen generate` ומייצר .xcodeproj
  Sources/
    Engine/                    ← לוגיקה טהורה, ללא UIKit/SwiftUI. נבדקת ב-unit tests בלי סימולטור
      Models/                  ← Region, Pathogen/UpgradeTree, Strain, Scenario, Achievement, GameState
      Simulation/               ← OutbreakSimulationEngine, WorldResponseEngine (מנוע חוקים), DailyChallenge, ReportAnalyzer
    ViewModels/                 ← MVVM: GameViewModel, HomeViewModel, ReportViewModel
    Views/                      ← SwiftUI: Home, Map, UpgradeTree, Game HUD, Report
    Design/                     ← Theme (צבעים/טיפוגרפיה) + קומפוננטות משותפות
    Services/                   ← Sound/Haptic, AdManager (AdMob), ConsentManager (ATT+UMP/GDPR), Localization
    Persistence/                ← Core Data (היסטוריית דוחות + הישגים)
    App/                        ← @main, Router, RootView, Info.plist config
  Resources/
    Localizations/{en,he}.lproj/Localizable.strings
    Assets.xcassets
  Tests/PathogenProtocolTests/  ← unit tests למנוע (ר' "בדיקות" למטה)
```

**הפרדת שכבות**: `Sources/Engine` לא מייבא SwiftUI/UIKit בכלל — כל חוקי המשחק הם
פונקציות טהורות `GameState -> GameState`. זה מה שמאפשר לכתוב unit tests ישירות,
בלי סימולטור (עמידה בדרישת סעיף 8.2 בפרומפט המקורי).

## מנוע התגובה העולמית — לא AI

`WorldResponseEngine` הוא סט חוקים דטרמיניסטי ומתועד (`WorldResponseRules.swift`):
עדכון מודעות הוא נוסחה ישירה (זיהוי × קטלניות, מרוסן ע"י עמידות-גילוי), מחקר
נצבר בקצב **קבוע** לפי רמת קושי ברגע שהמודעות חוצה סף — כך שניתן לחשב מראש בדיוק
את "יום התרופה" הצפוי (`GameState.projectedCureDay`), וסגר נכנס לתוקף ע"י תנאי
if/else ברור על מודעות אזורית. שום דבר לא אקראי ושום למידת-מכונה לא מעורבת.

## בדיקות

`Tests/PathogenProtocolTests` מכסה: כל חוק במנוע התגובה העולמית, מנוע הסימולציה
היומי (כולל משחק מלא עד ניצחון/הפסד ודטרמיניזם), תקינות עץ השדרוגים, קביעות
האתגר היומי, סיווג דוח הסיום, והישגים. הרצה:

```bash
xcodegen generate
xcodebuild test -project PathogenProtocol.xcodeproj -scheme PathogenProtocol \
  -destination "platform=iOS Simulator,name=iPhone 16"
```

**חשוב — שקיפות**: הסביבה שבה נכתב הפרויקט הזה היא קונטיינר Linux ללא Xcode/macOS,
ולכן **לא הצלחתי להריץ בפועל** את `xcodebuild`/`xcodegen` או לפתוח את האפליקציה
בסימולטור כדי לאמת קומפילציה מקצה-לקצה. הקוד נכתב בקפידה ונבדק ידנית שורה-שורה,
אך כל שינוי ב-Xcode עלול לחשוף שגיאת type-checking קטנה שרק הקומפיילר יתפוס.
**לפני כל שימוש רציני**: פתחו את `PathogenProtocol.xcodeproj` (אחרי `xcodegen generate`)
ב-Xcode, ודאו build ירוק, והריצו את סוויטת הבדיקות — זה הצעד הראשון שהייתי עושה
בעצמי אילו הייתה לי גישה ל-macOS.

## הרצה מקומית

1. התקינו [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
2. `cd PathogenProtocol && xcodegen generate`
3. פתחו את `PathogenProtocol.xcodeproj` ב-Xcode 15+
4. הריצו על סימולטור iPhone (מומלץ לבדוק גם iPhone SE וגם iPhone Pro Max — ר'
   צ'קליסט למטה)

## Secrets ו-CI/CD

ראו [`SECRETS.md`](SECRETS.md) לרשימה המדויקת של GitHub Secrets הנדרשים, ו-
[`APPLE_DEVELOPER_SETUP.md`](APPLE_DEVELOPER_SETUP.md) להדרכה ליצירת קבצי Apple
Developer. ה-workflow עצמו: `.github/workflows/pathogen-protocol-ios.yml`.

## פרטיות ומטא-דאטה

[`PRIVACY_POLICY.md`](PRIVACY_POLICY.md) ו-[`APP_STORE_METADATA.md`](APP_STORE_METADATA.md)
מוכנים להעתקה ישירה ל-App Store Connect (עברית + אנגלית).

## צ'קליסט "לפני מסירה" (סעיף 8.9)

- [x] Unit tests לכל מודול לוגי (מנוע התפשטות, תגובה עולמית, נקודות אבולוציה, עץ שדרוגים, אתגר יומי, הישגים)
- [x] הפרדת שכבות: Engine ללא UIKit/SwiftUI
- [x] Type safety: enums לכל הישויות (UpgradeCategory, DifficultyLevel, GameOutcome וכו')
- [x] Logger: אין `print` בקוד — שגיאות Core Data עוברות ב-`assertionFailure` (קורס בדיבאג, שקט בפרודקשן ע"י Core Data's own recovery path)
- [x] נגישות: `accessibilityLabel`/`accessibilityValue`/`accessibilityHint` על מפת האזורים ועץ השדרוגים
- [x] RTL: `environment(\.layoutDirection)` מוזרם מ-`LocalizationManager` לפי שפת המכשיר; כל הטקסטים דרך `Localizable.strings`
- [x] Light/Dark Mode: כל הצבעים דרך `AppColor` עם וריאנטים אדפטיביים, בלי `preferredColorScheme` קבוע
- [ ] **טרם בוצע (דורש Xcode בפועל)**: build ירוק בפועל, הרצה על iPhone SE ו-Pro Max, בדיקת VoiceOver מקצה-לקצה, ולידציית App Icon (ר' למטה)
- [ ] App Icon: `Resources/Assets.xcassets/AppIcon.appiconset` מוגדר אך **ריק מתמונה** — יש להוסיף קובץ 1024×1024 לפני ארכוב לחנות
- [ ] Ad unit IDs אמיתיים: `AdUnitID.swift` משתמש ב-Test IDs של Google תמיד ב-Debug; יש להזין ID אמיתיים דרך `Info.plist` keys (`AdMobInterstitialUnitID` וכו') ב-Release, ור' SECRETS.md

## מגבלות ידועות / החלטות מכוונות

- **GoogleMobileAds / GoogleUserMessagingPlatform** נוספו כ-Swift Package dependencies
  ב-`project.yml`. גרסאות מדויקות (`from: 11.0.0` / `from: 2.3.0`) הן הגרסאות היציבות
  העדכניות נכון לכתיבת קוד זה — כדאי לוודא ב-Xcode שהן עדיין הגרסאות הרצויות ולעדכן
  אם צריך, מכיוון שלא ניתן היה לאמת resolution בפועל בסביבה הזו.
- מפת העולם היא גרף מופשט של 6 "אזורים" גנריים (לא מדינות אמיתיות), עם מיקומים
  קבועים ב-`RegionLayout.swift` — עיצוב flat, לא הקרנה גיאוגרפית.
