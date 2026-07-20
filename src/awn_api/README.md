# 🎓 Blind Assistance API - Graduation Project

## 📝 وصف المشروع
API متكامل لمساعدة المكفوفين باستخدام الذكاء الاصطناعي

## 🎯 المميزات
- 🪙 التعرف على العملات المصرية
- 👁️ التعرف على الأشياء في المشهد
- 📄 قراءة النصوص (OCR)
- 📏 تقدير المسافات

## 🚀 التشغيل

### 1. تثبيت المتطلبات
```bash
pip install -r requirements.txt
```

### 2. تشغيل السيرفر
```bash
cd app
python main.py
```

### 3. فتح الـ Documentation
```
http://localhost:8000/docs
```

## 📡 الـ Endpoints
- `GET /` - معلومات الـ API
- `GET /health` - فحص صحة النظام
- `POST /api/v1/detect-currency` - التعرف على العملات
- `POST /api/v1/detect-objects` - التعرف على الأشياء
- `POST /api/v1/read-text` - قراءة النصوص
- `POST /api/v1/estimate-distance` - تقدير المسافات

## 🧪 الاختبار
```bash
python tests/test_api.py
```

## 📁 هيكل المشروع
```
blind_assistance_api/
├── app/
│   ├── main.py
│   ├── config.py
│   ├── models/
│   ├── api/
│   └── utils/
├── tests/
├── models_weights/
└── docs/
```
# blind_assistance
