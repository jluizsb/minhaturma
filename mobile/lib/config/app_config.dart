class AppConfig {
  static const String appName = 'MinhaTurma';
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );
  static const String googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  static const int locationUpdateIntervalSeconds = 30;
  static const int locationHistoryDays = 7;
  static const int maxUploadSizeMB = 50;
}
