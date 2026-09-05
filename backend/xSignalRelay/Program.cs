using Microsoft.EntityFrameworkCore;
using xSignalRelay.Auth;
using xSignalRelay.Data;
using xSignalRelay.Endpoints;
using xSignalRelay.Services.Status;
using xSignalRelay.Signal;

var builder = WebApplication.CreateBuilder(args);

var signalBaseUrl = builder.Configuration["Signal:BaseUrl"] ?? "http://localhost:8080";
var dbPath = builder.Configuration["Db:Path"] ?? "relay.db";

builder.Services.AddDbContext<RelayDbContext>(options =>
    options.UseSqlite($"Data Source={dbPath}"));

builder.Services.AddHttpClient<ISignalSender, SignalJsonRpcSender>(client =>
{
    client.BaseAddress = new Uri(signalBaseUrl);
    client.Timeout = TimeSpan.FromSeconds(30);
});

builder.Services.AddSingleton<ISignalStatusRegistry, SignalStatusRegistry>();
builder.Services.AddHostedService<SignalHealthCheckService>();

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var services = scope.ServiceProvider;
    var db = services.GetRequiredService<RelayDbContext>();
    db.Database.Migrate();
    DbSeeder.Seed(db, builder.Configuration, services.GetRequiredService<ILogger<Program>>());
}

// Сторінка статусу на "/" (wwwroot/index.html) + її API — без авторизації, як дашборд xBot.
app.UseDefaultFiles();
app.UseStaticFiles();

app.MapGet("/health", () => Results.Ok(new { status = "ok" }));
app.MapGet("/api/status", (ISignalStatusRegistry registry) => registry.Get());

var api = app.MapGroup("").AddEndpointFilter<ApiKeyFilter>();
api.MapSendEndpoints();
api.MapCatalogEndpoints();

app.Run();
