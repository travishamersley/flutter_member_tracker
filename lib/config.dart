class Config {
  // TODO: Replace with your actual Client IDs from Google Cloud Console
  static const String webClientId =
      '859064477394-r6q96l9sg4oivhis18j3evdek6gqerkv.apps.googleusercontent.com';
  // Android/iOS Client IDs are configured in google-services.json / Info.plist respectively,
  // but google_sign_in handles them largely automatically if configured correctly.

  static const List<String> scopes = [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive.file', // Required to create/search files
  ];
}
