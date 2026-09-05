namespace xSignalRelay.Services.Status;

/// <summary>
/// In-memory статус Signal для сторінки на "/". Живе, поки живе процес — персистентність
/// не потрібна (за зразком BotStatusRegistry у xBot).
/// </summary>
public interface ISignalStatusRegistry
{
    SignalStatus Get();

    /// <summary>signal-cli daemon відповів (health check).</summary>
    void ReportOnline(string version);

    /// <summary>signal-cli daemon недоступний.</summary>
    void ReportOffline(string reason);

    /// <summary>Повідомлення надіслано — додає запис в історію (останні 5).</summary>
    void ReportSent(string description);
}
