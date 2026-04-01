# AI Health - Theo dõi sức khỏe thông minh bằng AI

Ứng dụng Flutter theo dõi chỉ số sức khỏe của bệnh nhân, kết nối với **HealthKit (iOS)** và **Health Connect (Android)** để thu thập dữ liệu IoMT, sau đó sử dụng **Google Gemini AI** để phân tích và đưa ra lời khuyên sức khỏe cá nhân hóa.

## 📋 Tính năng

### Chỉ số sức khỏe theo dõi
- ❤️ **Nhịp tim (Heart Rate)** - Liên tục
- 🩸 **Huyết áp (Blood Pressure)** - Tâm thu / Tâm trương
- 🍬 **Đường huyết (Blood Glucose)** - Liên tục hoặc đan đoạn
- 🫁 **SpO2** - Nồng độ oxy trong máu
- 🌡️ **Nhiệt độ cơ thể (Body Temperature)**
- 👟 **Bước chân (Steps)**

### Tính năng chính
- 📱 Kết nối **Apple HealthKit** (iOS) và **Google Health Connect** (Android)
- 🤖 **AI Gemini** phân tích dữ liệu và đưa lời khuyên sức khỏe
- 📊 **Biểu đồ xu hướng** trực quan cho từng chỉ số
- ⚠️ **Cảnh báo** khi chỉ số vượt ngưỡng bình thường
- 📝 Nhập dữ liệu thủ công
- 📈 Thống kê (trung bình, cao nhất, thấp nhất)

## 🏗️ Kiến trúc

```
lib/
├── main.dart                          # Entry point
├── models/
│   ├── health_data_point.dart         # Health data model
│   └── health_advice.dart             # AI advice model
├── services/
│   ├── health_service.dart            # HealthKit/Health Connect integration
│   └── ai_health_advisor.dart         # Google Gemini AI service
├── providers/
│   └── health_provider.dart           # State management (Provider)
├── utils/
│   └── app_theme.dart                 # App theme & colors
└── ui/
    ├── screens/
    │   ├── dashboard_screen.dart      # Main dashboard
    │   ├── metric_detail_screen.dart  # Detail view for each metric
    │   ├── ai_advice_screen.dart      # AI advice screen
    │   ├── manual_input_screen.dart   # Manual data entry
    │   └── settings_screen.dart       # App settings
    └── widgets/
        ├── health_metric_card.dart    # Metric card widget
        ├── health_summary_header.dart # Dashboard header
        └── ai_advice_card.dart        # AI advice card widget
```

## 🔧 Cài đặt

### Yêu cầu
- Flutter SDK >= 3.10.4
- Android: minSdk 26 (Health Connect)
- iOS: iOS 13+ (HealthKit)

### Bước 1: Cài đặt dependencies
```bash
flutter pub get
```

### Bước 2: Cấu hình Gemini API Key
Mở `lib/services/ai_health_advisor.dart` và thay:
```dart
static const String _apiKey = 'YOUR_GEMINI_API_KEY';
```
Lấy key tại: https://aistudio.google.com/app/apikey

### Bước 3: Cấu hình nền tảng

#### iOS (HealthKit)
- Xcode > Runner > Signing & Capabilities > Add Capability > HealthKit

#### Android (Health Connect)
- Cài đặt **Health Connect** từ Google Play Store

### Bước 4: Chạy
```bash
flutter run
```

## ⚠️ Lưu ý
> Ứng dụng chỉ cung cấp thông tin tham khảo, **KHÔNG thay thế tư vấn y tế chuyên nghiệp**.
