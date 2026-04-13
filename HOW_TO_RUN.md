# How to Compile and Run Membership Tracker

This document provides instructions on how to compile, run, and build the Membership Tracker application. Because this application is heavily designed to target the web using Google APIs for backend operations, you will mostly run it in a web browser.

## Prerequisites

1. **Flutter SDK**: Ensure you have installed and set up the [Flutter SDK](https://docs.flutter.dev/get-started/install). 
   - The project uses SDK version `>=3.10.8`.
   - Run `flutter doctor` to ensure your setup is complete.
2. **Google Cloud Project Setup**:
   Since the app integrates with Google Sign-In and Google Sheets for data access, ensure that the application is authorized via your Google Cloud OAuth Client credentials based on where it's being served (e.g. `localhost` during development).

## Running the App in Development

For local development and testing, you can run the app directly via the command line or from an IDE like VS Code or Android Studio.

### 1. Fetch Dependencies

Before running the app for the first time, or whenever `pubspec.yaml` is updated, fetch the project's dependencies:

```bash
flutter pub get
```

### 2. Run the App

The main target for this app is the web. To launch the application in Chrome:

```bash
flutter run -d chrome
```

**Running in the Android Simulator (Emulator):**

If you want to run the app in an Android emulator:
1. List available emulators:
   ```bash
   flutter emulators
   ```
2. Launch the Android emulator (replace `<emulator_id>` with the ID from the listing):
   ```bash
   flutter emulators --launch <emulator_id>
   ```
3. Once the emulator is fully loaded, start the app:
   ```bash
   flutter run
   ```

**Running on a Physical Device via USB:**

If you want to run the app on a physical Android device:
1. Enable **Developer Options** and **USB Debugging** on your Android device (usually found in Settings > About phone > tap "Build number" 7 times).
2. Connect your device to your computer via USB.
3. If prompted on the device, tap "Allow USB debugging" to trust your computer.
4. Verify your device is connected and recognized by running:
   ```bash
   flutter devices
   ```
5. Run the app directly on the device (replace `<device_id>` with the device ID from the previous step):
   ```bash
   flutter run -d <device_id>
   ```

Alternatively, if you have multiple devices or emulators set up:

```bash
flutter run
```
And Flutter will prompt you to choose which device to run on.

*Note: If testing Google integration, make sure the local server port that Flutter uses for the web matches what you have set as an "Authorized JavaScript origin" in your Google Cloud platform credentials, or use a specific port:*
```bash
flutter run -d chrome --web-port=5000
```
Then, ensure `http://localhost:5000` is an authorized origin in Google Cloud console.

## Building for Production

When you are ready to deploy the application, you need to compile a release build.

### Building for the Web

To create a production release bundle for hosting on any web server or static CDN, run:

```bash
flutter build web
```

This will compile your Dart code to JavaScript and place the required assets inside the `build/web/` directory. You can then copy the contents of `build/web/` to your hosting provider.

### Building for Other Platforms

If you expand the app to other platforms (iOS, Android, Windows, macOS, Linux), you can build them using their respective sub-commands:

**Android APK:**
```bash
flutter build apk
```

**iOS (Requires macOS):**
```bash
flutter build ios
```

For more details on Flutter's buildup and deployment steps, see the documentation at [flutter.dev/docs/deployment](https://docs.flutter.dev/deployment).
