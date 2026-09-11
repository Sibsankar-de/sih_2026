# FineLine Navigator - Run Guide

FineLine Navigator is an AI/ML-assisted Inertial Dead Reckoning and Sensor Fusion navigation system developed in Flutter for Smart India Hackathon 2026 (Problem Statement: SIH26168).

---

## 1. Prerequisites

Before running the project, ensure you have the following installed on your machine:

- **Flutter SDK** (v3.0.0 or higher)  
  Verify installation:
  ```bash
  flutter --version
  ```
- **Android Studio / Android SDK** (for Android emulator or physical device deployment)
- **Google Chrome** (for running as a Web application)

Run Flutter Doctor to verify your environment setup:
```bash
flutter doctor
```

---

## 2. Setup & Installation

1. **Navigate to the project directory**:
   ```bash
   cd android_app
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

---

## 3. Running the Project

### Check Available Devices
List all connected devices, emulators, and browsers:
```bash
flutter devices
```

### Option A: Run on Web (Google Chrome)
The application includes a synthetic sensor simulation engine, making it fully functional in web browsers:
```bash
flutter run -d chrome
```

### Option B: Run on Android (Emulator or Physical Device)
1. Start an Android Virtual Device (AVD) from Android Studio or connect a physical Android device with USB Debugging enabled.
2. Launch the app:
   ```bash
   flutter run -d android
   ```
   *(Or specify the device ID listed by `flutter devices`)*

### Option C: Run with Default Device
If only one device or emulator is active:
```bash
flutter run
```

---

## 4. Building the Project

### Build Android APK
```bash
flutter build apk --release
```
The generated APK will be located at:
`build/app/outputs/flutter-apk/app-release.apk`

### Build Web Release
```bash
flutter build web --release
```
The output will be generated in `build/web/`.

---

## 5. Troubleshooting & Useful Commands

- **Clear Build Cache:**
  ```bash
  flutter clean
  flutter pub get
  ```

- **Run Static Analysis:**
  ```bash
  flutter analyze
  ```
