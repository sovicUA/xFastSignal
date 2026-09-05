namespace xSignalRelay.Services.Status;

public sealed class SignalStatusRegistry : ISignalStatusRegistry
{
    /// <summary>Скільки останніх надісланих повідомлень тримати на сторінці.</summary>
    private const int MaxHistory = 5;

    private readonly Lock _gate = new();
    private SignalStatus _status = new(
        SignalState.Unknown,
        Version: null,
        LastActivityUtc: null,
        LastMessage: "Очікування першої перевірки",
        History: []);

    public SignalStatus Get()
    {
        lock (_gate)
            return _status;
    }

    public void ReportOnline(string version)
    {
        lock (_gate)
            _status = _status with { State = SignalState.Online, Version = version };
    }

    public void ReportOffline(string reason)
    {
        lock (_gate)
            _status = _status with { State = SignalState.Error, LastMessage = reason };
    }

    public void ReportSent(string description)
    {
        lock (_gate)
        {
            var entry = new SignalActivityEntry(DateTime.UtcNow, description);
            _status = _status with
            {
                LastActivityUtc = entry.TimestampUtc,
                LastMessage = description,
                History = _status.History.Prepend(entry).Take(MaxHistory).ToList(),
            };
        }
    }
}
