using Microsoft.EntityFrameworkCore;
using xSignalRelay.Contracts;
using xSignalRelay.Data;
using xSignalRelay.Services.Status;
using xSignalRelay.Signal;
using xSignalRelay.Templating;

namespace xSignalRelay.Endpoints;

public static class SendEndpoints
{
    public static void MapSendEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPost("/send", async (
            SendRequest body,
            RelayDbContext db,
            ISignalSender signal,
            ISignalStatusRegistry status,
            ILogger<SendMarker> log,
            CancellationToken ct) =>
        {
            if (string.IsNullOrWhiteSpace(body.TemplateId) || string.IsNullOrWhiteSpace(body.Target))
                return Results.BadRequest(new { error = "templateId і target обов'язкові" });

            var template = await db.Templates
                .FirstOrDefaultAsync(t => t.Id == body.TemplateId && t.Enabled, ct);
            if (template is null)
                return Results.NotFound(new { error = $"Шаблон '{body.TemplateId}' не знайдено" });

            var recipient = await db.Recipients
                .FirstOrDefaultAsync(r => r.Id == body.Target && r.Enabled, ct);
            if (recipient is null)
                return Results.Json(
                    new { error = $"Одержувач '{body.Target}' не в allowlist" },
                    statusCode: StatusCodes.Status403Forbidden);

            string message;
            try
            {
                message = PlaceholderParser.Render(template.Body, body.Params);
            }
            catch (TemplateRenderException ex)
            {
                return Results.BadRequest(new { error = ex.Message, key = ex.Key });
            }

            try
            {
                if (recipient.Kind == RecipientKind.Group)
                    await signal.SendToGroupAsync(message, recipient.Value, ct);
                else
                    await signal.SendToContactAsync(message, recipient.Value, ct);
            }
            catch (Exception ex)
            {
                log.LogError(ex, "Не вдалось надіслати шаблон {TemplateId} до {RecipientId}", template.Id, recipient.Id);
                return Results.Json(
                    new { error = "signal-cli не зміг надіслати повідомлення" },
                    statusCode: StatusCodes.Status502BadGateway);
            }

            log.LogInformation("Надіслано шаблон {TemplateId} до {RecipientId}", template.Id, recipient.Id);
            status.ReportSent($"{recipient.DisplayName} ← «{template.Name}»");
            return Results.Accepted(value: new { sent = true });
        })
        .WithSummary("Надіслати шаблон одержувачу")
        .WithDescription(
            "`target` — це `id` з /recipients, не номер телефону. `params` обов'язкові, якщо шаблон має плейсхолдери.\n\n" +
            "202 — прийнято; 400 — немає полів / бракує значення плейсхолдера; 404 — немає шаблону; " +
            "403 — одержувач не в allowlist; 502 — signal-cli не надіслав.")
        .Produces(StatusCodes.Status202Accepted)
        .Produces(StatusCodes.Status400BadRequest)
        .Produces(StatusCodes.Status403Forbidden)
        .Produces(StatusCodes.Status404NotFound)
        .Produces(StatusCodes.Status502BadGateway);
    }

    /// <summary>Категорія логера для ендпоінта /send.</summary>
    public sealed class SendMarker;
}
