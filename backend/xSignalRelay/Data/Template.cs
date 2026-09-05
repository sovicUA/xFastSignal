using System.ComponentModel.DataAnnotations;

namespace xSignalRelay.Data;

/// <summary>
/// Шаблон повідомлення. <see cref="Body"/> може містити плейсхолдери виду {key}, що
/// підставляються зі значень у запиті /send. Шаблон без плейсхолдерів — готовий текст.
/// </summary>
public sealed class Template
{
    /// <summary>Стабільний slug, яким клієнт посилається на шаблон (напр. "running-late").</summary>
    [Key]
    [MaxLength(64)]
    public string Id { get; set; } = string.Empty;

    [MaxLength(128)]
    public string Name { get; set; } = string.Empty;

    [MaxLength(4000)]
    public string Body { get; set; } = string.Empty;

    public bool Enabled { get; set; } = true;
}
