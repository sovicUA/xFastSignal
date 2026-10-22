import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/catalog.dart';
import '../models/quick_action.dart';
import '../providers.dart';
import '../services/quick_actions_store.dart';
import '../services/relay_client.dart';

/// Створення / редагування кнопки: шаблон, одержувач, параметри (зафіксовані або
/// «питати при тапі»), власний підпис. Шаблони й одержувачі — з каталогу relay.
class ActionEditorScreen extends ConsumerWidget {
  const ActionEditorScreen({super.key, this.initial});

  /// `null` — нова кнопка.
  final QuickAction? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);

    return Scaffold(
      appBar: AppBar(title: Text(initial == null ? 'Нова кнопка' : 'Кнопка')),
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Не вдалося отримати шаблони й одержувачів: ${e is RelayException ? e.message : e}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                OutlinedButton(onPressed: () => ref.invalidate(catalogProvider), child: const Text('Повторити')),
              ],
            ),
          ),
        ),
        data: (c) => c == null
            ? const Center(child: Text('Спершу налаштуйте relay'))
            : _EditorForm(catalog: c, initial: initial),
      ),
    );
  }
}

class _EditorForm extends ConsumerStatefulWidget {
  const _EditorForm({required this.catalog, this.initial});

  final Catalog catalog;
  final QuickAction? initial;

  @override
  ConsumerState<_EditorForm> createState() => _EditorFormState();
}

class _EditorFormState extends ConsumerState<_EditorForm> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  RelayTemplate? _template;
  RelayRecipient? _recipient;

  /// Параметр → «питати при тапі».
  final Map<String, bool> _ask = {};
  final Map<String, TextEditingController> _values = {};

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial == null) return;
    _labelController.text = initial.label;
    _template = widget.catalog.templates.where((t) => t.id == initial.templateId).firstOrNull;
    _recipient = widget.catalog.recipients.where((r) => r.id == initial.recipientId).firstOrNull;
    for (final p in _template?.params ?? const <String>[]) {
      final fixed = initial.fixed[p];
      _ask[p] = fixed == null;
      _controllerFor(p).text = fixed ?? '';
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    for (final c in _values.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String param) => _values.putIfAbsent(param, TextEditingController.new);

  void _selectTemplate(RelayTemplate? template) => setState(() {
        _template = template;
        for (final p in template?.params ?? const <String>[]) {
          _ask.putIfAbsent(p, () => true);
        }
      });

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final template = _template!;
    final recipient = _recipient!;
    final action = QuickAction(
      id: widget.initial?.id ?? newQuickActionId(),
      templateId: template.id,
      templateName: template.name,
      recipientId: recipient.id,
      recipientName: recipient.displayName,
      recipientKind: recipient.kind,
      params: template.params,
      fixed: {
        for (final p in template.params)
          if (_ask[p] == false) p: _controllerFor(p).text.trim(),
      },
      label: _labelController.text.trim(),
    );
    await ref.read(quickActionsProvider.notifier).put(action);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Видалити кнопку?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Скасувати')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Видалити')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(quickActionsProvider.notifier).remove(widget.initial!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.initial;
    final template = _template;
    final stale = initial != null && (template == null || _recipient == null);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (stale) ...[
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: const ListTile(
                leading: Icon(Icons.warning_amber),
                title: Text('Шаблону або одержувача цієї кнопки на relay вже немає — виберіть знову'),
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Значення — id, не об'єкти: каталог може перезавантажитись під час редагування.
          DropdownButtonFormField<String>(
            initialValue: template?.id,
            decoration: const InputDecoration(labelText: 'Шаблон', border: OutlineInputBorder()),
            items: [
              for (final t in widget.catalog.templates) DropdownMenuItem(value: t.id, child: Text(t.name)),
            ],
            onChanged: (id) => _selectTemplate(widget.catalog.templates.where((t) => t.id == id).firstOrNull),
            validator: (v) => v == null ? 'Виберіть шаблон' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _recipient?.id,
            decoration: const InputDecoration(labelText: 'Одержувач', border: OutlineInputBorder()),
            items: [
              for (final r in widget.catalog.recipients)
                DropdownMenuItem(
                  value: r.id,
                  child: Row(
                    children: [
                      Icon(r.kind == RecipientKind.group ? Icons.group : Icons.person, size: 20),
                      const SizedBox(width: 8),
                      Text(r.displayName),
                    ],
                  ),
                ),
            ],
            onChanged: (id) =>
                setState(() => _recipient = widget.catalog.recipients.where((r) => r.id == id).firstOrNull),
            validator: (v) => v == null ? 'Виберіть одержувача' : null,
          ),
          for (final p in template?.params ?? const <String>[]) ...[
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Параметр «$p»'),
              subtitle: Text(_ask[p] == false ? 'Зафіксоване значення' : 'Питати при тапі'),
              value: _ask[p] ?? true,
              onChanged: (ask) => setState(() => _ask[p] = ask),
            ),
            if (_ask[p] == false)
              TextFormField(
                controller: _controllerFor(p),
                decoration: InputDecoration(labelText: 'Значення «$p»', border: const OutlineInputBorder()),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Вкажіть значення або «Питати при тапі»' : null,
              ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _labelController,
            decoration: InputDecoration(
              labelText: 'Підпис кнопки (необов\'язково)',
              hintText: template?.name,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Зберегти')),
          if (initial != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Видалити кнопку'),
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
