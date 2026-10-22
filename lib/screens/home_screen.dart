import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/catalog.dart';
import '../models/quick_action.dart';
import '../providers.dart';
import '../services/quick_actions_store.dart';
import '../services/relay_client.dart';
import '../services/relay_settings.dart';
import 'action_editor_screen.dart';
import 'settings_screen.dart';

/// Скільки чекати після тапу до відправки — час на «Скасувати».
const Duration sendDelay = Duration(seconds: 3);

/// Головний екран: сітка кнопок «шаблон → одержувач». Тап — відправка (з відкладенням
/// [sendDelay] і «Скасувати»), довгий тап — редагування.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _openSettings(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(relaySettingsProvider);
    final configured = settings.valueOrNull?.isConfigured ?? false;

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
      floatingActionButton: configured
          ? FloatingActionButton(
              tooltip: 'Додати кнопку',
              onPressed: () => openActionEditor(context),
              child: const Icon(Icons.add),
            )
          : null,
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message(icon: Icons.error, text: 'Не вдалося прочитати налаштування: $e'),
        data: (s) => s.isConfigured
            ? const _ActionsGrid()
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

Future<void> openActionEditor(BuildContext context, [QuickAction? action]) => Navigator.of(context)
    .push(MaterialPageRoute<void>(builder: (_) => ActionEditorScreen(initial: action)));

class _ActionsGrid extends ConsumerStatefulWidget {
  const _ActionsGrid();

  @override
  ConsumerState<_ActionsGrid> createState() => _ActionsGridState();
}

class _ActionsGridState extends ConsumerState<_ActionsGrid> {
  /// Кнопки, що чекають [sendDelay] (таймер) або вже надсилаються (`null`).
  final Map<String, Timer?> _pending = {};

  @override
  void dispose() {
    // Вихід з екрана до кінця відкладення — відправку скасовано.
    for (final timer in _pending.values) {
      timer?.cancel();
    }
    super.dispose();
  }

  Future<void> _tap(QuickAction action) async {
    if (_pending.containsKey(action.id)) return;
    final client = ref.read(relayClientProvider);
    if (client == null) return;

    final params = {...action.fixed};
    if (action.askedParams.isNotEmpty) {
      final asked = await showDialog<Map<String, String>>(
        context: context,
        builder: (_) => _AskParamsDialog(action: action),
      );
      if (asked == null || !mounted) return;
      params.addAll(asked);
    }

    final messenger = ScaffoldMessenger.of(context);
    void cancel() {
      _pending.remove(action.id)?.cancel();
      if (mounted) setState(() {});
      messenger.hideCurrentSnackBar();
    }

    setState(() => _pending[action.id] = Timer(sendDelay, () => _send(client, action, params, messenger)));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Надсилаю «${action.title}» → ${action.recipientName}…'),
        duration: sendDelay,
        // Інакше snackbar з дією не зникає сам (Material 3)
        persist: false,
        action: SnackBarAction(label: 'Скасувати', onPressed: cancel),
      ));
  }

  Future<void> _send(
    RelayClient client,
    QuickAction action,
    Map<String, String> params,
    ScaffoldMessengerState messenger,
  ) async {
    if (mounted) setState(() => _pending[action.id] = null);
    final errorColor = Theme.of(messenger.context).colorScheme.error;
    String result;
    var ok = false;
    try {
      await client.send(templateId: action.templateId, target: action.recipientId, params: params);
      result = '✓ Надіслано: «${action.title}» → ${action.recipientName}';
      ok = true;
    } on RelayException catch (e) {
      result = '✗ «${action.title}»: ${e.message}';
    }
    _pending.remove(action.id);
    if (mounted) setState(() {});
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(result),
        backgroundColor: ok ? null : errorColor,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final actions = ref.watch(quickActionsProvider);
    if (actions.isEmpty) {
      return _Message(
        icon: Icons.touch_app_outlined,
        text: 'Ще немає кнопок. Кнопка — це шаблон + одержувач: один тап, і повідомлення пішло.',
        action: FilledButton.icon(
          onPressed: () => openActionEditor(context),
          icon: const Icon(Icons.add),
          label: const Text('Додати кнопку'),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisExtent: 132,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: actions.length,
      itemBuilder: (context, i) {
        final action = actions[i];
        return _ActionCard(
          action: action,
          pending: _pending.containsKey(action.id),
          onTap: () => _tap(action),
          onLongPress: () => openActionEditor(context, action),
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action, required this.pending, required this.onTap, required this.onLongPress});

  final QuickAction action;
  final bool pending;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = [
      for (final e in action.fixed.entries) '${e.key}: ${e.value}',
      for (final p in action.askedParams) '$p: ?',
    ].join(' · ');

    return Card.filled(
      color: theme.colorScheme.primaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: pending ? null : onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(action.recipientKind == RecipientKind.group ? Icons.group : Icons.person, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(action.recipientName, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  if (pending) const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
              const Spacer(),
              Text(
                action.title,
                style: theme.textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (details.isNotEmpty)
                Text(details, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

/// Значення параметрів «питати при тапі» перед відправкою.
class _AskParamsDialog extends StatefulWidget {
  const _AskParamsDialog({required this.action});

  final QuickAction action;

  @override
  State<_AskParamsDialog> createState() => _AskParamsDialogState();
}

class _AskParamsDialogState extends State<_AskParamsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers = {
    for (final p in widget.action.askedParams) p: TextEditingController(),
  };

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop({for (final e in _controllers.entries) e.key: e.value.text.trim()});
  }

  @override
  Widget build(BuildContext context) {
    final entries = _controllers.entries.toList();
    return AlertDialog(
      title: Text(widget.action.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, e) in entries.indexed)
              TextFormField(
                controller: e.value,
                autofocus: i == 0,
                decoration: InputDecoration(labelText: e.key),
                textInputAction: i == entries.length - 1 ? TextInputAction.send : TextInputAction.next,
                onFieldSubmitted: i == entries.length - 1 ? (_) => _submit() : null,
                validator: (v) => (v ?? '').trim().isEmpty ? 'Вкажіть значення' : null,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Скасувати')),
        FilledButton(onPressed: _submit, child: const Text('Надіслати')),
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
    return ListView(
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
