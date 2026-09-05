using System.Net.Http.Json;
using System.Text.Json;

namespace xSignalRelay.Signal;

/// <summary>
/// Клієнт signal-cli daemon через HttpClient (BaseAddress = Signal:BaseUrl). Тонкий порт
/// send-частини xBot SignalJsonRpcClient — цей сервіс лише надсилає, вхідний потік (SSE)
/// лишається за xBot.
/// </summary>
public sealed class SignalJsonRpcSender(HttpClient http, ILogger<SignalJsonRpcSender> logger) : ISignalSender
{
    private const int MaxAttempts = 3;
    private static readonly TimeSpan RetryDelay = TimeSpan.FromMilliseconds(500);

    public Task SendToContactAsync(string message, string e164, CancellationToken ct = default) =>
        SendAsync(new SignalSendParams { Message = message, Recipient = [e164] }, ct);

    public Task SendToGroupAsync(string message, string groupId, CancellationToken ct = default) =>
        SendAsync(new SignalSendParams { Message = message, GroupId = groupId }, ct);

    public async Task<string> GetVersionAsync(CancellationToken ct = default)
    {
        var request = new SignalJsonRpcRequest<SignalEmptyParams> { Method = "version", Params = new SignalEmptyParams() };

        var response = await http.PostAsJsonAsync("/api/v1/rpc", request, ct);
        response.EnsureSuccessStatusCode();

        var rpc = await response.Content.ReadFromJsonAsync<SignalJsonRpcResponse<SignalVersionResult>>(ct);
        if (rpc?.Error is { } error)
            throw new InvalidOperationException($"signal-cli JSON-RPC помилка {error.Code}: {error.Message}");

        return rpc?.Result?.Version ?? "невідомо";
    }

    /// <summary>
    /// До 3 спроб з невеликою паузою: на "холодному старті" (щойно піднятий daemon) перший
    /// виклик іноді падає з "Failed to send message" без деталей, а миттєвий ідентичний повтор
    /// проходить (емпірика xBot, 2026-08-10). Для сповіщень втрачена відправка гірша за рідкісний дубль.
    /// </summary>
    private async Task SendAsync(SignalSendParams @params, CancellationToken ct)
    {
        for (var attempt = 1; ; attempt++)
        {
            try
            {
                await SendOnceAsync(@params, ct);
                return;
            }
            catch (Exception ex) when (attempt < MaxAttempts)
            {
                logger.LogWarning(ex, "Signal send: спроба {Attempt}/{Max} не вдалась, повтор через {Delay}",
                    attempt, MaxAttempts, RetryDelay);
                await Task.Delay(RetryDelay, ct);
            }
        }
    }

    private async Task SendOnceAsync(SignalSendParams @params, CancellationToken ct)
    {
        var request = new SignalJsonRpcRequest<SignalSendParams> { Method = "send", Params = @params };

        var response = await http.PostAsJsonAsync("/api/v1/rpc", request, ct);
        if (!response.IsSuccessStatusCode)
        {
            var body = await response.Content.ReadAsStringAsync(ct);
            logger.LogError("Signal send failed: {Status} {Body}", response.StatusCode, body);
            response.EnsureSuccessStatusCode();
        }

        var rpc = await response.Content.ReadFromJsonAsync<SignalJsonRpcResponse<JsonElement>>(ct);
        if (rpc?.Error is { } error)
            throw new InvalidOperationException($"signal-cli JSON-RPC помилка {error.Code}: {error.Message}");
    }
}
