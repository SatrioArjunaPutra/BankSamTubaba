/// Konfigurasi dari --dart-define saat build/run.
///
///   flutter run --dart-define=API_URL=https://staging.example.com/api/v1
///   flutter run --dart-define=USE_MOCK=true
class Config {
  /// Default untuk emulator Android (10.0.2.2 = localhost komputer).
  static const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://127.0.0.1:8000/api/v1');

  /// true → semua request dijawab backend palsu di memori (lib/core/api/mock_backend.dart).
  static const useMock = bool.fromEnvironment('USE_MOCK');
}
