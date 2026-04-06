class Config {
  // TODO: Replace with your actual Web Client ID from Google Cloud Console
  static const String webClientId =
      '859064477394-r6q96l9sg4oivhis18j3evdek6gqerkv.apps.googleusercontent.com';
  // NOTE ON ANDROID CONFIGURATION:
  // Android native authentication does NOT need a Client ID here.
  // Instead, you must register your Android app's SHA-1 fingerprint within your Google Cloud project's OAuth 2.0 Credentials.
  // See the Walkthrough for detailed steps.

  static const List<String> scopes = [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive.file', // Required to create/search files
    'https://www.googleapis.com/auth/drive.appdata', // Required for hidden app data backup
  ];
}
