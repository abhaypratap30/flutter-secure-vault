# 🛡️ Vault — Privacy & Security Mobile Application

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Architecture](https://img.shields.io/badge/Architecture-Clean%20%2F%20BLoC-ff69b4?style=for-the-badge)](https://bloclibrary.dev)
[![Security](https://img.shields.io/badge/Encryption-AES--256--CBC-green?style=for-the-badge)](https://en.wikipedia.org/wiki/Advanced_Encryption_Standard)
[![License](https://img.shields.io/badge/License-MIT-blue.style=for-the-badge)](LICENSE)

**Vault** is a privacy-first mobile application built with Flutter. It provides military-grade **AES-256 encryption** for photos, videos, and private notes, paired with stealth camouflage features, dual-session decoy vaults, biometric authentication, and cloud backup capabilities.

Designed following **Clean Architecture** principles and state management powered by **Flutter BLoC**, Vault serves as an open-source demonstration of modern, production-grade Flutter development.

---

## ✨ Key Features

### 🔐 Security & Cryptography
* **AES-256 CBC Encryption**: All media assets and text notes are encrypted on-device before being saved to local storage.
* **Master & Decoy PIN Sessions**: Entering a secondary Decoy PIN opens an isolated, decoy vault containing dummy data to protect against coercion.
* **Biometric Authentication**: Fingerprint and Face ID unlock powered by platform hardware security modules (`local_auth` & `flutter_secure_storage`).
* **SHA-256 PIN Hashing**: Passcodes are hashed with SHA-256 before storage; raw passcodes are never saved to disk.

### 🕵️ Stealth & Panic Features
* **Search Engine Camouflage**: Option to disguise the passcode entry screen as a functional web search engine.
* **Fake Crash Protocol**: Entering a designated crash PIN triggers a realistic OS system alert dialog.
* **Touch Rhythm Lock**: Pattern-based unlock utilizing custom tap time interval analysis.
* **Flip-to-Hide Panic Lock**: Sensor-driven auto-locking when device is flipped face-down.
* **Bluetooth Proximity Key**: Optional lock constraint requiring specific paired Bluetooth devices.

### 📸 Media & Note Management
* **Photo & Video Encryption**: Import media directly from gallery with automatic original file cleanup.
* **In-Memory Streaming**: Photos and videos are decrypted on-the-fly into RAM for secure previewing without disk exposure.
* **Encrypted Notes Editor**: Full text-note editor featuring real-time character counters and auto-save on exit.
* **Gallery Restoration**: Unhide and restore encrypted media back into the public device gallery at any time.

### ☁️ Cloud Backup & Recovery
* **Firebase Cloud Sync**: Anonymous Firebase Authentication coupled with Cloud Storage and Firestore for encrypted backups.
* **Graceful Mock Fallback**: Automatic offline mock mode ensures 100% functionality even without Firebase configuration.

### 🎨 Modern UI & Glassmorphism Design
* **Glassmorphic Aesthetics**: Modern backdrop blur, smooth micro-animations, glowing ambient backdrops, and liquid UI components.
* **Dynamic Theme Engine**: Real-time theme switching between 4 curated color palettes (*Violet, Cyan, Emerald, Sakura*).

---

## 🏗️ Architecture & Project Structure

Vault is structured following a **Layered Clean Architecture** pattern:

```
lib/
├── core/                       # Core utilities & global constants
│   ├── theme/                  # Theme configuration & palettes
│   └── utils/                  # Helper utilities & hashing routines
├── data/                       # Data layer (Models & Services)
│   ├── models/
│   │   ├── vault_item.dart     # Encrypted media asset metadata model
│   │   └── vault_note.dart     # Encrypted secure note model
│   └── services/
│       ├── backup_service.dart # Firebase Cloud Sync & Mock implementation
│       └── vault_service.dart  # AES-256 encryption & session management
├── logic/                      # Business Logic Layer (BLoC)
│   └── blocs/
│       ├── auth_bloc.dart      # Passcode verification & biometric BLoC
│       ├── backup_bloc.dart    # Cloud sync & data recovery BLoC
│       ├── media_bloc.dart     # Encrypted media management BLoC
│       ├── notes_bloc.dart     # Secure notes CRUD BLoC
│       └── theme_bloc.dart     # Dynamic theme switching BLoC
├── presentation/               # UI Layer (Screens & Widgets)
│   ├── screens/
│   │   ├── backup_screen.dart          # Cloud backup & recovery UI
│   │   ├── dashboard_screen.dart       # Main tabbed gallery & settings
│   │   ├── gallery_picker_screen.dart  # Media selector & importer
│   │   ├── media_viewer_screen.dart    # Photo zoom & video player
│   │   ├── note_editor_screen.dart     # Secure text note editor
│   │   └── passcode_screen.dart        # PIN pad & camouflage UI
│   └── widgets/
│       ├── animated_background.dart    # Glowing aurora background
│       └── glass_box.dart              # Reusable glassmorphic card
└── main.dart                   # Application entry point & BLoC providers
```

---

## 🛠️ Technology Stack & Dependencies

* **Framework**: [Flutter](https://flutter.dev) (Dart 3.x)
* **State Management**: [flutter_bloc](https://pub.dev/packages/flutter_bloc)
* **Cryptography**: [encrypt](https://pub.dev/packages/encrypt), [crypto](https://pub.dev/packages/crypto)
* **Biometrics & Storage**: [local_auth](https://pub.dev/packages/local_auth), [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage), [shared_preferences](https://pub.dev/packages/shared_preferences)
* **Media & Gallery**: [photo_manager](https://pub.dev/packages/photo_manager), [video_player](https://pub.dev/packages/video_player), [sensors_plus](https://pub.dev/packages/sensors_plus)
* **Backend Sync**: [firebase_core](https://pub.dev/packages/firebase_core), [firebase_auth](https://pub.dev/packages/firebase_auth), [cloud_firestore](https://pub.dev/packages/cloud_firestore), [firebase_storage](https://pub.dev/packages/firebase_storage)

---

## 🚀 Getting Started

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.19+)
* Android Studio / Xcode for device simulation
* Java Development Kit (JDK 17+)

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/your-username/vault.git
   cd vault
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Firebase Configuration (Optional)**:
   * By default, the app automatically falls back to **Simulated Cloud Mode** if Firebase is not configured.
   * To connect your own Firebase project:
     - Copy `android/app/google-services.json.template` to `android/app/google-services.json` and insert your Firebase credentials.
     - Enable **Anonymous Authentication**, **Firestore**, and **Firebase Storage** in your Firebase console.

4. **Run the application**:
   ```bash
   flutter run
   ```

---

## 🛡️ Security Audit & Threat Model

* **Zero Plaintext Disk Exposure**: Raw photo, video, and note data are never written to disk in unencrypted format.
* **Memory Protection**: Encryption keys derived from PINs are retained in memory only for the duration of an unlocked session and purged immediately upon locking.
* **Separation of Master & Decoy Environments**: Decoy vault sessions use entirely separate directories and metadata manifests (`decoy_vault_storage/metadata.json`), ensuring zero data overlap.

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and submitting pull requests.

---

## 📜 License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.
