using System.Security.Cryptography;
using System.Text;

namespace xSignalRelay.Auth;

/// <summary>
/// Захист самих сторінок Swagger (<c>/swagger</c>) та OpenAPI-документа (<c>/openapi</c>)
/// поза Development. Приймає ключ або як <c>X-Api-Key</c> (curl), або як Basic-пароль —
/// браузер сам покаже вікно входу (будь-який логін, пароль = ApiKey).
/// </summary>
public static class SwaggerAccess
{
    public const string Realm = "xSignalRelay Swagger";

    public static bool IsAuthorized(HttpContext context, string? apiKey)
    {
        if (string.IsNullOrEmpty(apiKey))
            return false;

        var headerKey = context.Request.Headers[ApiKeyFilter.HeaderName].ToString();
        if (Matches(headerKey, apiKey))
            return true;

        var auth = context.Request.Headers.Authorization.ToString();
        if (!auth.StartsWith("Basic ", StringComparison.OrdinalIgnoreCase))
            return false;

        string decoded;
        try
        {
            decoded = Encoding.UTF8.GetString(Convert.FromBase64String(auth["Basic ".Length..].Trim()));
        }
        catch (FormatException)
        {
            return false;
        }

        var separator = decoded.IndexOf(':');
        var password = separator >= 0 ? decoded[(separator + 1)..] : decoded;
        return Matches(password, apiKey);
    }

    private static bool Matches(string provided, string expected) =>
        !string.IsNullOrEmpty(provided) &&
        CryptographicOperations.FixedTimeEquals(
            Encoding.UTF8.GetBytes(provided),
            Encoding.UTF8.GetBytes(expected));
}
