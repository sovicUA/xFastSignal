import 'catalog.dart';

/// Кнопка на головному екрані: шаблон → одержувач (+ параметри). Зберігається лише на
/// телефоні. Назви й параметри — знімок каталогу на момент створення, щоб сітка
/// показувалась і відправлялась одним тапом без запиту каталогу; якщо шаблон чи
/// одержувача на сервері прибрали, `/send` поверне помилку.
class QuickAction {
  const QuickAction({
    required this.id,
    required this.templateId,
    required this.templateName,
    required this.recipientId,
    required this.recipientName,
    required this.recipientKind,
    this.params = const [],
    this.fixed = const {},
    this.label = '',
  });

  factory QuickAction.fromJson(Map<String, dynamic> json) => QuickAction(
        id: json['id'] as String,
        templateId: json['templateId'] as String,
        templateName: json['templateName'] as String,
        recipientId: json['recipientId'] as String,
        recipientName: json['recipientName'] as String,
        recipientKind: json['recipientKind'] == 'group' ? RecipientKind.group : RecipientKind.contact,
        params: (json['params'] as List<dynamic>? ?? const []).cast<String>(),
        fixed: (json['fixed'] as Map<String, dynamic>? ?? const {}).cast<String, String>(),
        label: json['label'] as String? ?? '',
      );

  final String id;
  final String templateId;
  final String templateName;
  final String recipientId;
  final String recipientName;
  final RecipientKind recipientKind;

  /// Плейсхолдери шаблону (`{minutes}` → `minutes`).
  final List<String> params;

  /// Зафіксовані значення параметрів; решту з [params] питаємо при тапі.
  final Map<String, String> fixed;

  /// Власний підпис кнопки; порожній — назва шаблону.
  final String label;

  String get title => label.isNotEmpty ? label : templateName;

  /// Параметри, значення яких вводяться при кожному тапі.
  List<String> get askedParams => [for (final p in params) if (!fixed.containsKey(p)) p];

  Map<String, dynamic> toJson() => {
        'id': id,
        'templateId': templateId,
        'templateName': templateName,
        'recipientId': recipientId,
        'recipientName': recipientName,
        'recipientKind': recipientKind == RecipientKind.group ? 'group' : 'contact',
        'params': params,
        'fixed': fixed,
        'label': label,
      };
}
