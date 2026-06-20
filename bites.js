const biteSeeds=[
['ביוכימיה','Von Gierke','חסר Glucose-6-phosphatase','היפוגליקמיה קשה בצום, חמצת לקטית והגדלת כבד.','HIGH'],
['ביוכימיה','Lesch-Nyhan','חסר HGPRT','עודף uric acid, דיסטוניה ופגיעה עצמית; X-linked.','HIGH'],
['אימונולוגיה','CGD','חסר NADPH oxidase','אין respiratory burst; זיהומי catalase-positive ו-DHR חריג.','HIGH'],
['אימונולוגיה','DiGeorge','מחיקת 22q11','חסר T cells, hypocalcemia ומומי conotruncal.','HIGH'],
['מיקרוביולוגיה','S aureus','Protein A נקשר ל-Fc של IgG','מונע opsonization; החיידק catalase ו-coagulase חיובי.','HIGH'],
['מיקרוביולוגיה','Cholera toxin','הפעלת Gs ועליית cAMP','הפרשת כלור ומים גורמת לשלשול rice-water.','HIGH'],
['פרמקולוגיה','ACE inhibitors','הרחבת efferent arteriole','מורידים לחץ גלומרולרי; שיעול, angioedema והיפרקלמיה.','HIGH'],
['פרמקולוגיה','Aminoglycosides','קישור בלתי הפיך ל-30S','Nephrotoxicity, ototoxicity וחסימה נוירומוסקולרית.','HIGH'],
['לב','Aortic stenosis','SAD: syncope, angina, dyspnea','אוושה סיסטולית לקרוטידים ו-hypertrophy קונצנטרית.','HIGH'],
['ריאות','Pulmonary embolism','V/Q גבוה — dead space','האוורור נשמר אך הפרפוזיה יורדת.','HIGH'],
['ריאות','Emphysema','Compliance עולה ו-DLCO יורד','הרס elastic tissue גורם air trapping.','HIGH'],
['כליות','SIADH','Euvolemic hypotonic hyponatremia','שתן מרוכז באופן לא מתאים; ללא בצקת משמעותית.','HIGH'],
['אנדוקרינולוגיה','Addison disease','Cortisol נמוך ו-ACTH גבוה','היפרפיגמנטציה, hypotension ו-hyperkalemia.','HIGH'],
['נוירולוגיה','Broca aphasia','דיבור לא שוטף והבנה שמורה','פגיעה ב-inferior frontal gyrus הדומיננטי.','HIGH'],
['המטולוגיה','TTP','חסר ADAMTS13','vWF multimers גורמים MAHA ו-thrombocytopenia.','HIGH'],
['גסטרו','Celiac disease','IgA anti-tTG','Villous atrophy ו-dermatitis herpetiformis.','MEDIUM'],
['פתולוגיה','Granuloma','TNF-α מתחזק גרנולומות','חסימת TNF עלולה להפעיל מחדש שחפת.','MEDIUM'],
['כליות','NSAIDs','כיווץ afferent arteriole','עיכוב prostaglandins מוריד GFR.','MEDIUM'],
['נוירולוגיה','Brown-Séquard','Ipsilateral motor/vibration loss','כאב וטמפרטורה אובדים contralaterally.','MEDIUM'],
['ביוסטטיסטיקה','Sensitivity','מעט false negatives','בדיקה רגישה שלילית שוללת: SnNout.','MEDIUM']
];
function makeBites(){const prompts=['מהו הקישור המרכזי?','השלימו את ה-Bite','איזה מנגנון חייבים לזכור?','מהי אסוציאציית הבחינה?','אמרו את התשובה לפני הגילוי'];const contexts=['Rapid recall','Clinical link','Mechanism','Exam trap','Last-minute','Morning set','Night set','Weakness drill','Mastery check','Mixed review'];const out=[];let id=0;for(const b of biteSeeds)for(const p of prompts)for(const c of contexts)for(let v=1;v<=3;v++)out.push({id:`B-${++id}`,system:b[0],concept:b[1],front:p,answer:b[2],detail:b[3],yield:b[4],context:c,variant:v});return out}const bites=makeBites();
