namespace xSignalRelay.Contracts;

/// <summary>Тіло POST /send.</summary>
/// <param name="TemplateId">Slug шаблону.</param>
/// <param name="Target">Opaque Id одержувача з allowlist.</param>
/// <param name="Params">Значення плейсхолдерів {key} шаблону, якщо є.</param>
public sealed record SendRequest(string TemplateId, string Target, Dictionary<string, string>? Params);

public sealed record TemplateDto(string Id, string Name, IReadOnlyList<string> Params);

public sealed record RecipientDto(string Id, string Kind, string DisplayName);
