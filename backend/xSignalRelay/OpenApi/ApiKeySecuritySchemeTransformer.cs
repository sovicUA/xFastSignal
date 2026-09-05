using Microsoft.AspNetCore.OpenApi;
using Microsoft.OpenApi;
using xSignalRelay.Auth;

namespace xSignalRelay.OpenApi;

/// <summary>
/// Додає в OpenAPI-документ схему безпеки <c>X-Api-Key</c> (кнопка «Authorize» у Swagger UI)
/// і глобальну вимогу її вказувати. <c>/health</c> та <c>/api/status</c> ключ ігнорують —
/// замочок біля них суто косметичний.
/// </summary>
internal sealed class ApiKeySecuritySchemeTransformer : IOpenApiDocumentTransformer
{
    public Task TransformAsync(OpenApiDocument document, OpenApiDocumentTransformerContext context, CancellationToken cancellationToken)
    {
        var scheme = new OpenApiSecurityScheme
        {
            Type = SecuritySchemeType.ApiKey,
            In = ParameterLocation.Header,
            Name = ApiKeyFilter.HeaderName,
            Description = $"Ключ доступу в заголовку {ApiKeyFilter.HeaderName} — для /send, /templates, /recipients.",
        };

        document.Components ??= new OpenApiComponents();
        document.Components.SecuritySchemes ??= new Dictionary<string, IOpenApiSecurityScheme>();
        document.Components.SecuritySchemes[ApiKeyFilter.HeaderName] = scheme;

        document.Security ??= [];
        document.Security.Add(new OpenApiSecurityRequirement
        {
            [new OpenApiSecuritySchemeReference(ApiKeyFilter.HeaderName, document)] = [],
        });

        return Task.CompletedTask;
    }
}
