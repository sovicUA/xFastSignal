import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/quick_action.dart';
import 'relay_settings.dart';

const String _actionsKey = 'quick_actions';

/// Кнопки головного екрана в порядку показу; JSON у SharedPreferences.
class QuickActionsController extends Notifier<List<QuickAction>> {
  @override
  List<QuickAction> build() {
    final raw = ref.read(sharedPreferencesProvider).getString(_actionsKey);
    if (raw == null) return const [];
    return [
      for (final e in jsonDecode(raw) as List<dynamic>) QuickAction.fromJson(e as Map<String, dynamic>),
    ];
  }

  /// Додає нову кнопку в кінець або замінює наявну з тим самим `id`.
  Future<void> put(QuickAction action) async {
    final actions = [...state];
    final index = actions.indexWhere((a) => a.id == action.id);
    if (index < 0) {
      actions.add(action);
    } else {
      actions[index] = action;
    }
    await _save(actions);
  }

  Future<void> remove(String id) => _save([for (final a in state) if (a.id != id) a]);

  Future<void> _save(List<QuickAction> actions) async {
    state = actions;
    await ref.read(sharedPreferencesProvider).setString(_actionsKey, jsonEncode(actions));
  }
}

final quickActionsProvider =
    NotifierProvider<QuickActionsController, List<QuickAction>>(QuickActionsController.new);

/// Новий унікальний `id` кнопки.
String newQuickActionId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);
