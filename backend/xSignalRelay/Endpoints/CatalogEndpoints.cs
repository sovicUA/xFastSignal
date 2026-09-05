using Microsoft.EntityFrameworkCore;
using xSignalRelay.Contracts;
using xSignalRelay.Data;
using xSignalRelay.Templating;

namespace xSignalRelay.Endpoints;

/// <summary>Довідники для UI клієнта: доступні шаблони та одержувачі (без сирих значень).</summary>
public static class CatalogEndpoints
{
    public static void MapCatalogEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/templates", async (RelayDbContext db, CancellationToken ct) =>
        {
            var templates = await db.Templates
                .Where(t => t.Enabled)
                .OrderBy(t => t.Name)
                .ToListAsync(ct);

            var dtos = templates
                .Select(t => new TemplateDto(t.Id, t.Name, PlaceholderParser.Names(t.Body)))
                .ToList();

            return Results.Ok(dtos);
        });

        app.MapGet("/recipients", async (RelayDbContext db, CancellationToken ct) =>
        {
            var dtos = await db.Recipients
                .Where(r => r.Enabled)
                .OrderBy(r => r.DisplayName)
                .Select(r => new RecipientDto(r.Id, r.Kind.ToString(), r.DisplayName))
                .ToListAsync(ct);

            return Results.Ok(dtos);
        });
    }
}
