import fs from "node:fs/promises";
import path from "node:path";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const outputDir = path.resolve("outputs/iomt_health_report");
await fs.mkdir(outputDir, { recursive: true });

const workbook = Workbook.create();

const palette = {
  navy: "#17324D",
  teal: "#0F766E",
  blue: "#2563EB",
  green: "#16A34A",
  amber: "#D97706",
  red: "#DC2626",
  gray: "#F3F4F6",
  line: "#D1D5DB",
  text: "#111827",
  muted: "#6B7280",
  white: "#FFFFFF",
};

const sources = [
  ["S1", "Google Health Connect - Availability", "https://developer.android.com/health-and-fitness/health-connect/availability", "Health Connect yeu cau Android 9+, Android 14+ tich hop trong Settings."],
  ["S2", "Google Health Connect - Data types", "https://developer.android.com/health-and-fitness/guides/health-connect/data-and-data-types/data-types", "Cac nhom data va record nhu Activity, Body Measurement, Sleep, Vitals, Wellness."],
  ["S3", "Android Developers Blog - Health Connect integrations", "https://android-developers.googleblog.com/2022/11/leading-health-and-fitness-apps-roll-out-health-connect-integrations.html", "Google neu Health Connect ho tro 40+ data types va cac app nhu MyFitnessPal, Oura, Peloton."],
  ["S4", "Apple Support - Manage Health data", "https://support.apple.com/en-us/108779", "Apple Health nhan du lieu tu iPhone, Apple Watch, app va Bluetooth devices; co quyen, source priority."],
  ["S5", "Apple Support - Apple Watch measurement accuracy", "https://support.apple.com/en-us/105002", "Wrist Detection, fit, Heart Rate privacy va dieu kien cam bien anh huong do du lieu."],
  ["S6", "Apple Support - ECG on Apple Watch", "https://support.apple.com/en-us/120278", "ECG can Apple Watch Series 4+ hoac Ultra, khong ho tro Apple Watch SE; luu trong Health app."],
];

const overview = [
  ["Noi dung", "Ket luan"],
  ["Kien truc dong bo", "Thiet bi -> app hang -> Health Connect / Apple HealthKit -> ung dung cua minh"],
  ["Health Connect", "Nen tang Android; doc/ghi du lieu suc khoe theo schema chuan, co quyen theo tung loai du lieu."],
  ["HealthKit / Apple Health", "Nen tang iOS; nhan du lieu tu iPhone, Apple Watch, app va phu kien tuong thich."],
  ["Uoc luong chi so", "Health Connect: 40+ data types; Apple Health/HealthKit voi Apple Watch doi moi: khoang 15-25 nhom IoMT pho bien, mo rong hon neu co thiet bi ben thu ba."],
  ["Ket luan khi thieu chi so", "Khong nen ket luan ngay la loi HealthKit/Health Connect; can kiem tra sensor, app hang, quyen, source priority, thoi gian query va trang thai sync."],
];

const devices = [
  ["Nhom thiet bi", "Vi du", "Nen tang phu hop", "Duong dong bo", "Chi so co the lay", "Rui ro/gioi han", "Nguon"],
  ["Apple Watch", "Series, SE, Ultra", "HealthKit", "Apple Watch -> Apple Health -> App", "Steps, distance, calories, workout, heart rate, HRV, resting HR, sleep, respiratory rate, wrist temperature, VO2 max, ECG/SpO2 tuy model", "ECG khong co tren SE; SpO2/ECG phu thuoc model, khu vuc, OS va cai dat", "S4; S5; S6"],
  ["Wear OS smartwatch", "Samsung Galaxy Watch, Pixel Watch", "Health Connect", "Watch -> Samsung Health/Fitbit/Google Health -> Health Connect -> App", "Activity, workout, steps, calories, heart rate, sleep, SpO2, body composition tuy model", "Mot so chi so rieng cua hang khong ghi ra Health Connect", "S1; S2; S3"],
  ["Fitness band", "Fitbit Charge/Inspire, Xiaomi Band, Huawei Band", "Health Connect / HealthKit tuy app", "Band -> app hang -> Health Connect/Apple Health", "Steps, sleep, heart rate, calories, SpO2/HRV tuy model", "Can app hang ho tro ghi data; iOS co the kem day du hon Android", "S2; S4"],
  ["Smart ring", "Oura Ring, Ultrahuman Ring", "Health Connect / HealthKit", "Ring -> app hang -> Health platform", "Sleep, heart rate, HRV, respiratory rate, skin/body temperature trend, activity", "Score nhu Readiness/Recovery co the la proprietary, khong phai schema chuan", "S2; S3; S4"],
  ["Smart scale", "Withings, Garmin Index, Xiaomi", "Health Connect / HealthKit", "Scale -> app hang -> Health platform", "Weight, BMI, body fat, body water, bone mass, lean mass tuy can", "Chi so body composition phu thuoc model va app co ghi hay khong", "S2; S4"],
  ["Blood pressure monitor", "Withings BPM, Omron", "Health Connect / HealthKit", "Device -> app hang -> Health platform", "Systolic, diastolic, pulse", "Can thiet bi y te va app ho tro write; khong phai smartwatch nao cung do huyet ap chuan", "S2; S4"],
  ["Glucose/CGM", "Dexcom, Abbott, app glucose", "Health Connect / HealthKit", "Device/app -> Health platform", "Blood glucose, thoi diem do, co the co nguon clinical/app", "Phu thuoc vung, thiet bi, quy dinh y te va API cua hang", "S2; S4"],
  ["Nutrition/workout apps", "MyFitnessPal, Peloton, Lifesum, Strava", "Health Connect / HealthKit", "App -> Health platform", "Workout, exercise session, calories, nutrition, hydration", "Du lieu la app-generated, khong phai sensor truc tiep", "S3; S4"],
];

const metrics = [
  ["Chi so", "Health Connect", "HealthKit/Apple Health", "Muc uu tien IoMT", "Dieu kien/ghi chu", "Nguon"],
  ["Steps", "Co", "Co", "Co ban", "De lay nhat; iPhone/phone va watch deu co the tao data", "S2; S4"],
  ["Distance", "Co", "Co", "Co ban", "Thuong tu GPS/accelerometer/workout", "S2; S4"],
  ["Calories burned", "Co", "Co", "Co ban", "Active/total calories phu thuoc device va profile nguoi dung", "S2; S5"],
  ["Exercise/workout session", "Co", "Co", "Co ban", "Can nguoi dung start workout hoac app tu nhan dien", "S2; S5"],
  ["Heart rate", "Co", "Co", "Nang cao", "Bi anh huong boi do deo, tattoo, chuyen dong, Heart Rate privacy", "S2; S5"],
  ["Resting heart rate", "Co", "Co", "Nang cao", "Apple Watch can Wrist Detection bat de lay background readings", "S2; S5"],
  ["HRV", "Co", "Co", "Nang cao", "Khac nhau ve cach tinh giua hang; nen luu source", "S2; S4"],
  ["SpO2 / Oxygen saturation", "Co", "Co tuy model", "Nang cao", "Phu thuoc sensor, model, khu vuc va app hang", "S2; S4"],
  ["Respiratory rate", "Co", "Co", "Nang cao", "Thuong lay khi ngu/qua app thiet bi", "S2; S4"],
  ["Blood pressure", "Co", "Co", "Nang cao", "Can may do hoac dong ho/app co tinh nang do huyet ap", "S2; S4"],
  ["Blood glucose", "Co", "Co", "Nang cao", "Thuong tu CGM/may do/app nhap tay", "S2; S4"],
  ["Body temperature", "Co", "Co", "Nang cao", "Phu thuoc thermometer/app ho tro", "S2; S4"],
  ["Skin/wrist temperature", "Co", "Co tuy watch/ring", "Nang cao", "Dung nhu trend, khong nen xem la nhiet do y te tuyet doi", "S2; S4"],
  ["Sleep duration/stages", "Co", "Co", "Co ban/Nang cao", "Can deo khi ngu, pin, sleep settings va app hang sync", "S2; S4"],
  ["VO2 max / Cardio fitness", "Co", "Co", "Nang cao", "Thuong can workout ngoai troi du dieu kien", "S2; S5"],
  ["Weight", "Co", "Co", "Co ban", "Tu can thong minh hoac nhap tay", "S2; S4"],
  ["Body fat/body water/bone mass", "Co", "Co tuy app", "Mo rong", "Tu can body composition; khong phai can nao cung ghi du", "S2; S4"],
  ["ECG", "Khong phai record chuan pho bien trong Health Connect", "Co voi Apple Watch tuong thich", "Phu thuoc", "Apple Watch SE khong ho tro ECG; ECG luu trong Health app", "S6"],
  ["Readiness/Recovery/Stress score", "Thuong khong chuan", "Thuong khong chuan", "Phu thuoc", "Chi so proprietary cua hang, nen lay qua API hang neu can", "S2; S4"],
];

const issues = [
  ["Van de khi HealthKit khong lay duoc chi so", "Nguyen nhan kha nang cao", "Cach kiem tra", "Ket luan de ghi vao bao cao", "Nguon"],
  ["Khong co data ECG", "Dong ho khong co ECG hoac khong du dieu kien", "Kiem tra model: Apple Watch Series 4+ hoac Ultra; SE khong ho tro", "Do gioi han thiet bi/model, khong phai mac dinh loi HealthKit", "S6"],
  ["Khong co background heart rate/resting HR", "Wrist Detection tat, Heart Rate privacy tat, deo long", "Watch app -> Passcode/Privacy; kiem tra fit va du lieu trong Health", "Do setting/sensor condition", "S5"],
  ["App minh query khong co du lieu nhung Health app co", "Sai permission, sai type, sai date range, sai source priority", "Kiem tra authorization, Data Sources & Access, query khoang thoi gian co data", "Nghieng ve loi implementation hoac permission", "S4"],
  ["App hang co chi so nhung Apple Health khong co", "App hang khong write sang Apple Health hoac user chua bat share", "Health app -> Profile -> Apps; app hang -> data sharing settings", "Do app hang/permission, khong phai HealthKit", "S4"],
  ["Health Connect khong co chi so rieng cua hang", "Chi so proprietary khong nam trong schema chuan", "So sanh voi data types cua Health Connect", "Can API cua hang hoac bo qua chi so score", "S2"],
  ["Du lieu sync cham", "Bluetooth, background refresh, chua mo app hang, internet/cloud sync cham", "Mo app hang, sync manual, doi vai phut, kiem tra timestamp source", "Do pipeline sync", "S4"],
  ["SpO2/temperature khong lien tuc", "Thiet bi chi do khi ngu/thu cong hoac theo dot", "Xem chinh sach do cua model va timestamp data", "Khong phai mat data, ma tan suat do co gioi han", "S2; S5"],
  ["Gia tri sai/khong on dinh", "Do deo sai, tattoo, da lanh, chuyen dong, sensor tiep xuc kem", "Kiem tra fit, vi tri deo, calibration, dieu kien moi truong", "Do chat luong tin hieu sensor", "S5"],
];

function addSheet(name, rows, tableName, widths = []) {
  const sheet = workbook.worksheets.add(name);
  sheet.showGridLines = false;
  sheet.getRangeByIndexes(0, 0, rows.length, rows[0].length).values = rows;
  const used = sheet.getRangeByIndexes(0, 0, rows.length, rows[0].length);
  used.format = {
    font: { color: palette.text, name: "Aptos", size: 10 },
    wrapText: true,
    verticalAlignment: "top",
    borders: { preset: "inside", style: "thin", color: "#E5E7EB" },
  };
  const header = sheet.getRangeByIndexes(0, 0, 1, rows[0].length);
  header.format = {
    fill: palette.teal,
    font: { bold: true, color: palette.white, name: "Aptos", size: 10 },
    horizontalAlignment: "center",
    verticalAlignment: "middle",
    wrapText: true,
  };
  header.format.rowHeightPx = 36;
  sheet.freezePanes.freezeRows(1);
  const table = sheet.tables.add(`A1:${colName(rows[0].length)}${rows.length}`, true, tableName);
  table.style = "TableStyleMedium4";
  table.showFilterButton = true;
  widths.forEach((width, idx) => {
    if (width) sheet.getRangeByIndexes(0, idx, rows.length, 1).format.columnWidthPx = width;
  });
  used.format.autofitRows();
  return sheet;
}

function colName(n) {
  let s = "";
  while (n > 0) {
    const m = (n - 1) % 26;
    s = String.fromCharCode(65 + m) + s;
    n = Math.floor((n - 1) / 26);
  }
  return s;
}

const summary = workbook.worksheets.add("Tong quan");
summary.showGridLines = false;
summary.getRange("A1:F1").merge();
summary.getRange("A1").values = [["Bao cao dong bo du lieu IoMT voi Health Connect va HealthKit"]];
summary.getRange("A1").format = {
  fill: palette.navy,
  font: { bold: true, color: palette.white, size: 16, name: "Aptos Display" },
  horizontalAlignment: "left",
  verticalAlignment: "middle",
};
summary.getRange("A1").format.rowHeightPx = 42;
summary.getRange("A3:B8").values = overview;
summary.getRange("A3:B3").format = {
  fill: palette.teal,
  font: { bold: true, color: palette.white },
  horizontalAlignment: "center",
};
summary.getRange("A4:A8").format = { fill: "#E0F2F1", font: { bold: true, color: palette.text } };
summary.getRange("A3:B8").format = {
  wrapText: true,
  verticalAlignment: "top",
  borders: { preset: "all", style: "thin", color: palette.line },
};
summary.getRange("A10:F10").values = [["Chi so tong hop", "Gia tri", "Ghi chu", "Health Connect", "HealthKit", "Nguon"]];
summary.getRange("A11:F15").values = [
  ["So nhom thiet bi", 8, "Theo bang Thiet bi", "Co", "Co", "S1-S6"],
  ["So dong chi so trong file", metrics.length - 1, "Danh sach uu tien cho IoMT", "40+ schema chuan", "15-25 nhom voi Apple Watch doi moi", "S2; S4"],
  ["So van de test thuong gap", issues.length - 1, "Dung lam checklist QA", "Co", "Co", "S2; S4; S5; S6"],
  ["Uu tien tich hop", "Health Connect + HealthKit", "Can log source/timestamp de truy vet", "Android", "iOS", "S1; S4"],
  ["Ket luan", "Phu thuoc pipeline", "Device/app/permission/sync quan trong ngang API", "Dung", "Dung", "S2; S4"],
];
summary.getRange("A10:F10").format = {
  fill: palette.teal,
  font: { bold: true, color: palette.white },
  horizontalAlignment: "center",
};
summary.getRange("A10:F15").format = {
  wrapText: true,
  borders: { preset: "all", style: "thin", color: palette.line },
  verticalAlignment: "top",
};
summary.getRange("B11:B13").format.numberFormat = "#,##0";
summary.getRange("A:A").format.columnWidthPx = 190;
summary.getRange("B:B").format.columnWidthPx = 240;
summary.getRange("C:C").format.columnWidthPx = 280;
summary.getRange("D:F").format.columnWidthPx = 150;
summary.freezePanes.freezeRows(3);

addSheet("Thiet bi", devices, "DevicesTable", [180, 190, 150, 260, 340, 320, 110]);
addSheet("Chi so", metrics, "MetricsTable", [180, 120, 150, 140, 360, 110]);
addSheet("Van de HealthKit", issues, "IssuesTable", [260, 260, 330, 330, 110]);
addSheet("Nguon", [["ID", "Ten nguon", "URL", "Ghi chu"], ...sources], "SourcesTable", [70, 270, 560, 420]);

for (const sheetName of ["Tong quan", "Thiet bi", "Chi so", "Van de HealthKit", "Nguon"]) {
  const preview = await workbook.render({
    sheetName,
    autoCrop: "all",
    scale: 1,
    format: "png",
  });
  await fs.writeFile(
    path.join(outputDir, `${sheetName.replaceAll(" ", "_")}.png`),
    new Uint8Array(await preview.arrayBuffer()),
  );
}

const inspectSummary = await workbook.inspect({
  kind: "table",
  range: "Tong quan!A1:F15",
  include: "values,formulas",
  tableMaxRows: 20,
  tableMaxCols: 8,
  maxChars: 3000,
});
console.log(inspectSummary.ndjson);

const errors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 100 },
  summary: "final formula error scan",
});
console.log(errors.ndjson);

const xlsx = await SpreadsheetFile.exportXlsx(workbook);
await xlsx.save(path.join(outputDir, "bao_cao_dong_bo_iomt_healthconnect_healthkit.xlsx"));

