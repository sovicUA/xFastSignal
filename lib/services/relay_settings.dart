import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _baseUrlKey = 'relay_base_url';
const String _apiKeyKey = 'relay_api_key';

/// Заповнюється в `main()` через `overrideWithValue`.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider не ініціалізовано'),
);

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) => const FlutterSecureStorage());

/// Адреса relay і API-ключ. URL — у SharedPreferences, ключ — у secure storage
/// (Android Keystore).
class RelaySettings {
  const RelaySettings({required this.baseUrl, required this.apiKey});

  static const empty = RelaySettings(baseUrl: '', apiKey: '');

  final String baseUrl;
  final String apiKey;

  bool get isConfigured => baseUrl.isNotEmpty && apiKey.isNotEmpty;
}

class RelaySettingsController extends AsyncNotifier<RelaySettings> {
  @override
  Future<RelaySettings> build() async {
    final baseUrl = ref.read(sharedPreferencesProvider).getString(_baseUrlKey) ?? '';
    final apiKey = await ref.read(secureStorageProvider).read(key: _apiKeyKey) ?? '';
    return RelaySettings(baseUrl: baseUrl, apiKey: apiKey);
  }

  Future<void> save(RelaySettings settings) async {
    await ref.read(sharedPreferencesProvider).setString(_baseUrlKey, settings.baseUrl);
    await ref.read(secureStorageProvider).write(key: _apiKeyKey, value: settings.apiKey);
    state = AsyncData(settings);
  }
}

final relaySettingsProvider =
    AsyncNotifierProvider<RelaySettingsController, RelaySettings>(RelaySettingsController.new);

/// Нормалізує введену адресу: прибирає пробіли й кінцевий `/`.
/// Повертає `null`, якщо це не http(s)-URL.
String? normalizeBaseUrl(String input) {
  final trimmed = input.trim().replaceAll(RegExp(r'/+$'), '');
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) {
    return null;
  }
  return trimmed;
}
