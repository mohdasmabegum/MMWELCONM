# 🌈 MMWELCONN - Social Connection App

**Connect Your Mood. Share Your Status. Stay Close.**

A Flutter-based social connection app that lets you share your mood, status, location, and auto-messages with friends organized by relationship types.

---

## 📱 Download

**[Google Play Store - Coming Soon](https://play.google.com/store/apps/details?id=com.example.mmwelconn)**
*(Permanent URL - Updated after deployment to Phase 3)*

---

## ✨ Features

### Phase 1: Foundation MVP (Days 1-10) 🔄
- ✅ User Authentication (Login/Signup)
- ✅ Beautiful Home Screen with Animations
- ✅ Firestore Database Setup
- 🔄 Contact List Management
- 🔄 Real-time Chat System
- 🔄 Image Upload & Display

### Phase 2: Social Features (Days 11-20) 📝
- 🔄 Mood Status Widget
- 🔄 On-Call Status Detection
- 🔄 Busy Mode with Auto-Messages
- 🔄 Background Location Tracking
- 🔄 Chat Groups by Relationship Type

### Phase 3: Polish & Deploy (Days 21-30) 📝
- 🔄 Chat Themes & Animations
- 🔄 Dark Mode
- 🔄 Complete Testing & Optimization
- 🔄 **Google Play Store Deployment**
- 🔄 Demo Video & Documentation

---

## 🛠️ Tech Stack

| Component | Technology |
|-----------|-----------|
| Frontend | Flutter (iOS + Android) |
| Backend | Firebase |
| Authentication | Firebase Auth |
| Database | Cloud Firestore |
| Storage | Firebase Cloud Storage |
| Image Picker | `image_picker` package |
| Maps | `google_maps_flutter` (Phase 3) |

---

## 📋 DSA Algorithms Implemented

| Algorithm | Use Case | Phase |
|-----------|----------|-------|
| HashMap | O(1) contact lookup | Phase 1 |
| Merge Sort | Sort friends by mood | Phase 2 |
| Trie | Fast status search | Phase 2 |
| Dijkstra | Find nearest friend location | Phase 3 |
| Priority Queue | Widget update ordering | Phase 2 |
| Subset Sum | Chat group categorization | Phase 2 |

---

## 🚀 Getting Started

### Prerequisites
- Flutter 3.44.2+
- Android Studio
- Firebase Account
- VS Code

### Installation

```bash
# Clone repository
git clone https://github.com/mohdasmabegum/MMWELCONN.git
cd mmwelconn

# Get dependencies
flutter pub get

# Configure Firebase
flutterfire configure

# Run on emulator/device
flutter run
```

---

## 📁 Project Structure

```
mmwelconn/
├── lib/
│   ├── main.dart                      # App entry
│   ├── firebase_options.dart          # Firebase config
│   ├── screens/
│   │   ├── login_screen.dart          # Auth UI
│   │   ├── home_screen.dart           # Home with animations
│   │   ├── chat_screen.dart           # (Phase 1)
│   │   ├── contacts_screen.dart       # (Phase 1)
│   │   ├── mood_widget.dart           # (Phase 2)
│   │   └── location_screen.dart       # (Phase 3)
│   └── services/
│       ├── auth_service.dart          # Auth operations
│       ├── firestore_service.dart     # DB operations
│       └── storage_service.dart       # Image uploads
├── android/
│   └── app/
│       └── google-services.json       # Firebase Android config
└── pubspec.yaml                       # Dependencies
```

---

## 📊 Development Timeline

| Phase | Days | Timeline | Status |
|-------|------|----------|--------|
| **Foundation MVP** | 1-10 | Jun 18-27 | 🔄 In Progress |
| **Social Features** | 11-20 | Jun 28-Jul 7 | 📝 Upcoming |
| **Polish & Deploy** | 21-30 | Jul 8-17 | 📝 Upcoming |

---

## 🎨 Design Features

- 🌈 Gradient backgrounds (Blue → Purple → Pink)
- ✨ Smooth animations (Fade, Scale, Hover effects)
- 🖱️ Interactive hover effects on all buttons
- 🎭 Dark mode support (Phase 4)
- 📱 Fully responsive design

---

## 🔐 Security & Privacy

- Firebase Authentication (email/password)
- Firestore Security Rules
- Location privacy toggle
- User data deletion options
- End-to-end encryption (Future)

---

## 📸 Screenshots & Demo

(Coming Soon after Phase 1)
- Demo video: 5 minute walkthrough
- Screenshots: All screens

---

## 🎓 Academic & Career Value

**For:**
- ✅ JNTUH DAA Exam (Design & Analysis of Algorithms)
- ✅ GATE Exam Portfolio
- ✅ Job Interviews (FAANG Companies)
- ✅ Internship Applications (Infosys, TCS)
- ✅ GitHub Portfolio

**Demonstrates:**
- Full-stack app development
- Real-world DSA implementations
- Cloud backend integration
- UI/UX animation skills
- Deployment & publishing

---

## 🤝 Contributing

This is a personal portfolio project. Suggestions welcome:
- Create an issue for bugs/features
- Email for collaboration

---

## 📄 License

MIT License - Use freely for learning & portfolio projects.

---

## 📞 Contact

- **GitHub**: [@mohdasmabegum](https://github.com/mohdasmabegum)
- **Email**: mohdasmabegum@example.com

---

**Status**: 🔄 Active Development  
**Last Updated**: June 18, 2026  
**Version**: 0.1.0-alpha  
**Next Target**: Complete Phase 1 by June 27
