namespace xSignalRelay.Signal;

/// <summary>Надсилання повідомлень у Signal через signal-cli daemon. Send-only.</summary>
public interface ISignalSender
{
    /// <param name="textStyles">"start:length:STYLE" (UTF-16) — розмітка шаблону, <see cref="Templating.PlaceholderParser.RenderStyled"/>.</param>
    Task SendToContactAsync(string message, string e164, IReadOnlyList<string>? textStyles = null, CancellationToken ct = default);
    Task SendToGroupAsync(string message, string groupId, IReadOnlyList<string>? textStyles = null, CancellationToken ct = default);

    /// <summary>Версія signal-cli — використовується як health check daemon.</summary>
    Task<string> GetVersionAsync(CancellationToken ct = default);
}
