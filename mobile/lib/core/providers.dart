import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_controller.dart';
import 'api/api_client.dart';
import 'api/mock_backend.dart';
import 'config.dart';
import 'storage/token_storage.dart';

/// Di-override di test.
final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => Config.useMock ? MemoryTokenStorage() : SecureTokenStorage(),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    baseUrl: Config.apiUrl,
    tokenStorage: ref.watch(tokenStorageProvider),
    adapter: Config.useMock ? MockBackend() : null,
  );
  // 401 dari endpoint mana pun → logout otomatis & kembali ke login
  client.onSesiBerakhir = () => ref.read(authProvider.notifier).sesiBerakhir();
  return client;
});
