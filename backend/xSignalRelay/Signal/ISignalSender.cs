namespace xSignalRelay.Signal;

/// <summary>Надсилання повідомлень у Signal через signal-cli daemon. Send-only.</summary>
public interface ISignalSender
{
    Task SendToContactAsync(string message, string e164, CancellationToken ct = default);
    Task SendToGroupAsync(string message, string groupId, CancellationToken ct = default);
}
