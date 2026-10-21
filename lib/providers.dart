import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/catalog.dart';
import 'services/relay_client.dart';
import 'services/relay_settings.dart';

/// Клієнт relay за збереженими налаштуваннями; `null`, поки їх не задано.
final relayClientProvider = Provider<RelayClient?>((ref) {
  final settings = ref.watch(relaySettingsProvider).valueOrNull;
  if (settings == null || !settings.isConfigured) return null;
  return RelayClient(baseUrl: settings.baseUrl, apiKey: settings.apiKey);
});

/// Шаблони + одержувачі з relay. Оновлення — `ref.invalidate(catalogProvider)`.
final catalogProvider = FutureProvider<Catalog?>((ref) async {
  final client = ref.watch(relayClientProvider);
  return client?.catalog();
});
