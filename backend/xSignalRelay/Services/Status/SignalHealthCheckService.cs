using xSignalRelay.Signal;

namespace xSignalRelay.Services.Status;

/// <summary>
/// Періодично пінгує signal-cli daemon (метод "version") і оновлює <see cref="ISignalStatusRegistry"/>.
/// </summary>
public sealed class SignalHealthCheckService(
    IServiceScopeFactory scopeFactory,
    ISignalStatusRegistry registry,
    ILogger<SignalHealthCheckService> logger) : BackgroundService
{
    private static readonly TimeSpan Interval = TimeSpan.FromSeconds(30);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(Interval);
        do
        {
            await CheckAsync(stoppingToken);
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }

    private async Task CheckAsync(CancellationToken ct)
    {
        try
        {
            await using var scope = scopeFactory.CreateAsyncScope();
            var signal = scope.ServiceProvider.GetRequiredService<ISignalSender>();
            var version = await signal.GetVersionAsync(ct);
            registry.ReportOnline(version);
        }
        catch (OperationCanceledException)
        {
            // зупинка сервісу
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "signal-cli health check не пройшов");
            registry.ReportOffline($"signal-cli недоступний: {ex.Message}");
        }
    }
}
