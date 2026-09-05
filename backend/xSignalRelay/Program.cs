using Microsoft.EntityFrameworkCore;
using xSignalRelay.Auth;
using xSignalRelay.Data;
using xSignalRelay.Endpoints;
using xSignalRelay.OpenApi;
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

builder.Services.AddOpenApi(options => options.AddDocumentTransformer<ApiKeySecuritySchemeTransformer>());

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

app.MapGet("/health", () => Results.Ok(new { status = "ok" }))
    .ExcludeFromDescription();
app.MapGet("/api/status", (ISignalStatusRegistry registry) => registry.Get())
    .WithTags("Статус")
    .WithSummary("Поточний стан Signal для сторінки на \"/\" (без авторизації).");

// Swagger: поза Development сам UI і openapi.json — за ключем (X-Api-Key або Basic-пароль).
if (!app.Environment.IsDevelopment())
{
    app.Use(async (context, next) =>
    {
        var path = context.Request.Path;
        if ((path.StartsWithSegments("/swagger") || path.StartsWithSegments("/openapi"))
            && !SwaggerAccess.IsAuthorized(context, builder.Configuration["ApiKey"]))
        {
            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
            context.Response.Headers.WWWAuthenticate = $"Basic realm=\"{SwaggerAccess.Realm}\"";
            return;
        }

        await next();
    });
}

app.MapOpenApi();
app.UseSwaggerUI(options =>
{
    options.SwaggerEndpoint("/openapi/v1.json", "xSignalRelay v1");
    options.RoutePrefix = "swagger";
    options.DocumentTitle = "xSignalRelay API";
});

var api = app.MapGroup("").AddEndpointFilter<ApiKeyFilter>().WithTags("Signal Relay");
api.MapSendEndpoints();
api.MapCatalogEndpoints();

app.Run();
