using System.Text.Json.Serialization;

namespace xSignalRelay.Services.Status;

[JsonConverter(typeof(JsonStringEnumConverter<SignalState>))]
public enum SignalState
{
    /// <summary>Ще не було жодної перевірки.</summary>
    Unknown,

    /// <summary>signal-cli daemon відповідає.</summary>
    Online,

    /// <summary>signal-cli daemon недоступний або повернув помилку.</summary>
    Error,
}

/// <summary>Один запис короткої історії — надіслане повідомлення (шаблон → одержувач).</summary>
public record SignalActivityEntry(DateTime TimestampUtc, string Message);

public record SignalStatus(
    SignalState State,
    string? Version,
    DateTime? LastActivityUtc,
    string? LastMessage,
    IReadOnlyList<SignalActivityEntry> History);
