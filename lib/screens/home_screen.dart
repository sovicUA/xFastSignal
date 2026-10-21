import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/catalog.dart';
import '../providers.dart';
import '../services/relay_client.dart';
import '../services/relay_settings.dart';
import 'settings_screen.dart';

/// Головний екран. Поки що показує каталог relay (шаблони й одержувачі);
/// сітка кнопок «шаблон → одержувач» — наступний крок (див. NOTES.md).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _openSettings(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(relaySettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('xFastSignal'),
        actions: [
          IconButton(
            tooltip: 'Налаштування',
            icon: const Icon(Icons.settings),
            onPressed: () => _openSettings(context),
          ),
        ],
      ),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message(icon: Icons.error, text: 'Не вдалося прочитати налаштування: $e'),
        data: (s) => s.isConfigured
            ? const _CatalogView()
            : _Message(
                icon: Icons.link_off,
                text: 'Вкажіть адресу relay і API-ключ',
                action: FilledButton(
                  onPressed: () => _openSettings(context),
                  child: const Text('Налаштувати'),
                ),
              ),
      ),
    );
  }
}

class _CatalogView extends ConsumerWidget {
  const _CatalogView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(catalogProvider.future),
      child: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message(
          icon: Icons.cloud_off,
          text: e is RelayException ? e.message : '$e',
          action: OutlinedButton(
            onPressed: () => ref.invalidate(catalogProvider),
            child: const Text('Повторити'),
          ),
        ),
        data: (c) => c == null ? const SizedBox.shrink() : _CatalogList(catalog: c),
      ),
    );
  }
}

class _CatalogList extends StatelessWidget {
  const _CatalogList({required this.catalog});

  final Catalog catalog;

  @override
  Widget build(BuildContext context) {
    final header = Theme.of(context).textTheme.titleSmall;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        ListTile(title: Text('Шаблони', style: header)),
        for (final t in catalog.templates)
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: Text(t.name),
            subtitle: t.params.isEmpty ? null : Text('Параметри: ${t.params.join(', ')}'),
          ),
        const Divider(),
        ListTile(title: Text('Одержувачі', style: header)),
        for (final r in catalog.recipients)
          ListTile(
            leading: Icon(r.kind == RecipientKind.group ? Icons.group : Icons.person),
            title: Text(r.displayName),
          ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    // ListView, щоб RefreshIndicator працював і на екрані помилки.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
        Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 16),
        Text(text, textAlign: TextAlign.center),
        if (action != null) ...[
          const SizedBox(height: 16),
          Center(child: action),
        ],
      ],
    );
  }
}
