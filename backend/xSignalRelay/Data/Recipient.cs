using System.ComponentModel.DataAnnotations;

namespace xSignalRelay.Data;

public enum RecipientKind
{
    Contact,
    Group,
}

/// <summary>
/// Дозволений одержувач (allowlist). Клієнт бачить лише <see cref="Id"/> + <see cref="DisplayName"/>
/// + <see cref="Kind"/>; сирий <see cref="Value"/> (номер E.164 або base64 groupId) не залишає бекенд.
/// </summary>
public sealed class Recipient
{
    /// <summary>Opaque ідентифікатор для клієнта (напр. "mom", "family-group").</summary>
    [Key]
    [MaxLength(64)]
    public string Id { get; set; } = string.Empty;

    public RecipientKind Kind { get; set; }

    /// <summary>Номер у форматі E.164 (Contact) або base64 groupId (Group).</summary>
    [MaxLength(256)]
    public string Value { get; set; } = string.Empty;

    [MaxLength(128)]
    public string DisplayName { get; set; } = string.Empty;

    public bool Enabled { get; set; } = true;
}
