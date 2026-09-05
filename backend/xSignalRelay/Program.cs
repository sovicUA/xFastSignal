using Microsoft.EntityFrameworkCore;
using xSignalRelay.Auth;
using xSignalRelay.Data;
using xSignalRelay.Endpoints;
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

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var services = scope.ServiceProvider;
    var db = services.GetRequiredService<RelayDbContext>();
    db.Database.Migrate();
    DbSeeder.Seed(db, builder.Configuration, services.GetRequiredService<ILogger<Program>>());
}

app.MapGet("/health", () => Results.Ok(new { status = "ok" }));

var api = app.MapGroup("").AddEndpointFilter<ApiKeyFilter>();
api.MapSendEndpoints();
api.MapCatalogEndpoints();

app.Run();
