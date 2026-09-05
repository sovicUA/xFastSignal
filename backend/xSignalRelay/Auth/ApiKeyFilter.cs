using System.Security.Cryptography;
using System.Text;

namespace xSignalRelay.Auth;

/// <summary>Перевіряє заголовок X-Api-Key проти значення "ApiKey" з конфігурації.</summary>
public sealed class ApiKeyFilter(IConfiguration config) : IEndpointFilter
{
    public const string HeaderName = "X-Api-Key";

    public async ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        var expected = config["ApiKey"];
        if (string.IsNullOrEmpty(expected))
            return Results.Problem("ApiKey не налаштовано на сервері", statusCode: StatusCodes.Status500InternalServerError);

        var provided = context.HttpContext.Request.Headers[HeaderName].ToString();
        if (!CryptographicOperations.FixedTimeEquals(
                Encoding.UTF8.GetBytes(provided),
                Encoding.UTF8.GetBytes(expected)))
        {
            return Results.Unauthorized();
        }

        return await next(context);
    }
}
