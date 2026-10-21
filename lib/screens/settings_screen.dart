import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/relay_client.dart';
import '../services/relay_settings.dart';

/// Адреса relay + API-ключ, з перевіркою з'єднання перед збереженням.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _keyController = TextEditingController();
  bool _obscureKey = true;
  bool _checking = false;

  /// Результат останньої перевірки: (успіх, текст).
  (bool, String)? _checkResult;

  @override
  void initState() {
    super.initState();
    final current = ref.read(relaySettingsProvider).valueOrNull ?? RelaySettings.empty;
    _urlController.text = current.baseUrl;
    _keyController.text = current.apiKey;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  RelaySettings get _entered => RelaySettings(
        baseUrl: normalizeBaseUrl(_urlController.text) ?? '',
        apiKey: _keyController.text.trim(),
      );

  Future<void> _check() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _checking = true;
      _checkResult = null;
    });
    final settings = _entered;
    try {
      final catalog = await RelayClient(baseUrl: settings.baseUrl, apiKey: settings.apiKey).catalog();
      _checkResult = (
        true,
        'З\'єднання є: шаблонів — ${catalog.templates.length}, '
            'одержувачів — ${catalog.recipients.length}',
      );
    } on RelayException catch (e) {
      _checkResult = (false, e.message);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(relaySettingsProvider.notifier).save(_entered);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final result = _checkResult;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Налаштування')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Адреса relay',
                hintText: 'http://10.0.2.2:5180',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
              validator: (v) =>
                  normalizeBaseUrl(v ?? '') == null ? 'Потрібна адреса виду http(s)://host:port' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _keyController,
              decoration: InputDecoration(
                labelText: 'API-ключ',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _obscureKey ? 'Показати' : 'Сховати',
                  icon: Icon(_obscureKey ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureKey = !_obscureKey),
                ),
              ),
              obscureText: _obscureKey,
              autocorrect: false,
              enableSuggestions: false,
              validator: (v) => (v ?? '').trim().isEmpty ? 'Вкажіть ключ' : null,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _checking ? null : _check,
              icon: _checking
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.wifi_tethering),
              label: const Text('Перевірити з\'єднання'),
            ),
            if (result != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(result.$1 ? Icons.check_circle : Icons.error,
                      color: result.$1 ? Colors.green : colors.error),
                  const SizedBox(width: 8),
                  Expanded(child: Text(result.$2)),
                ],
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Зберегти')),
          ],
        ),
      ),
    );
  }
}
