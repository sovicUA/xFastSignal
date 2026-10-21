/// Шаблон повідомлення з `GET /templates`. Текст шаблону лишається на сервері —
/// клієнт знає лише назву та імена плейсхолдерів (`{minutes}` → `minutes`).
class RelayTemplate {
  const RelayTemplate({required this.id, required this.name, required this.params});

  factory RelayTemplate.fromJson(Map<String, dynamic> json) => RelayTemplate(
        id: json['id'] as String,
        name: json['name'] as String,
        params: (json['params'] as List<dynamic>? ?? const []).cast<String>(),
      );

  final String id;
  final String name;
  final List<String> params;
}

enum RecipientKind { contact, group }

/// Одержувач з allowlist (`GET /recipients`). `id` — opaque, сирий номер чи
/// groupId сервер не віддає.
class RelayRecipient {
  const RelayRecipient({required this.id, required this.kind, required this.displayName});

  factory RelayRecipient.fromJson(Map<String, dynamic> json) => RelayRecipient(
        id: json['id'] as String,
        kind: (json['kind'] as String).toLowerCase() == 'group'
            ? RecipientKind.group
            : RecipientKind.contact,
        displayName: json['displayName'] as String,
      );

  final String id;
  final RecipientKind kind;
  final String displayName;
}

/// Усе, що клієнт отримує від relay для побудови кнопок.
class Catalog {
  const Catalog({required this.templates, required this.recipients});

  final List<RelayTemplate> templates;
  final List<RelayRecipient> recipients;
}
