using System.Text.Json.Serialization;

namespace xSignalRelay.Signal;

/// <summary>
/// Запит до POST /api/v1/rpc signal-cli daemon (JSON-RPC 2.0). Урізаний порт з xBot
/// (Models/SignalModels.cs) — цей сервіс викликає лише метод "send".
/// </summary>
public sealed class SignalJsonRpcRequest<TParams>
{
    [JsonPropertyName("jsonrpc")] public string JsonRpc { get; set; } = "2.0";
    [JsonPropertyName("id")] public string Id { get; set; } = Guid.NewGuid().ToString("N");
    [JsonPropertyName("method")] public string Method { get; set; } = string.Empty;
    [JsonPropertyName("params")] public TParams? Params { get; set; }
}

/// <summary>Відповідь daemon: або <see cref="Result"/>, або <see cref="Error"/>.</summary>
public sealed class SignalJsonRpcResponse<TResult>
{
    [JsonPropertyName("result")] public TResult? Result { get; set; }
    [JsonPropertyName("error")] public SignalJsonRpcError? Error { get; set; }
}

public sealed class SignalJsonRpcError
{
    [JsonPropertyName("code")] public int Code { get; set; }
    [JsonPropertyName("message")] public string? Message { get; set; }
}

/// <summary>
/// Params для методу "send". Заповнюється або <see cref="Recipient"/>, або <see cref="GroupId"/> —
/// daemon працює в single-account режимі, "account" не передається.
/// </summary>
public sealed class SignalSendParams
{
    [JsonPropertyName("message")] public string Message { get; set; } = string.Empty;
    [JsonPropertyName("recipient")] public List<string>? Recipient { get; set; }
    [JsonPropertyName("groupId")] public string? GroupId { get; set; }
}
