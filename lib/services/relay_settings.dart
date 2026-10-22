import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'trusted_ca.dart';

const String _baseUrlKey = 'relay_base_url';
const String _apiKeyKey = 'relay_api_key';
const String _caNameKey = 'relay_ca_name';
const String _caPemKey = 'relay_ca_pem';

/// Заповнюється в `main()` через `overrideWithValue`.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider не ініціалізовано'),
);

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) => const FlutterSecureStorage());

/// Адреса relay, API-ключ і (необов'язково) CA для HTTPS. URL і сертифікат (не секрет) —
/// у SharedPreferences, ключ — у secure storage (Android Keystore).
class RelaySettings {
  const RelaySettings({required this.baseUrl, required this.apiKey, this.trustedCa});

  static const empty = RelaySettings(baseUrl: '', apiKey: '');

  final String baseUrl;
  final String apiKey;
  final TrustedCa? trustedCa;

  bool get isConfigured => baseUrl.isNotEmpty && apiKey.isNotEmpty;
}

class RelaySettingsController extends AsyncNotifier<RelaySettings> {
  @override
  Future<RelaySettings> build() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final baseUrl = prefs.getString(_baseUrlKey) ?? '';
    final apiKey = await ref.read(secureStorageProvider).read(key: _apiKeyKey) ?? '';
    final caName = prefs.getString(_caNameKey);
    final caPem = prefs.getString(_caPemKey);
    return RelaySettings(
      baseUrl: baseUrl,
      apiKey: apiKey,
      trustedCa: caName != null && caPem != null ? TrustedCa(name: caName, pem: caPem) : null,
    );
  }

  Future<void> save(RelaySettings settings) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_baseUrlKey, settings.baseUrl);
    await ref.read(secureStorageProvider).write(key: _apiKeyKey, value: settings.apiKey);
    final ca = settings.trustedCa;
    if (ca == null) {
      await prefs.remove(_caNameKey);
      await prefs.remove(_caPemKey);
    } else {
      await prefs.setString(_caNameKey, ca.name);
      await prefs.setString(_caPemKey, ca.pem);
    }
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
