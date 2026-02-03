class Config {
  // TODO: Replace with your actual Client IDs from Google Cloud Console
  static const String webClientId =
      '549040035575-3r921du7lrl48ltdci5mtv3v1slgvldb.apps.googleusercontent.com';
  // Android/iOS Client IDs are configured in google-services.json / Info.plist respectively,
  // but google_sign_in handles them largely automatically if configured correctly.

  static const List<String> scores = [
    'https://www.googleapis.com/auth/spreadsheets',
  ];
}
