using System.Text.RegularExpressions;

namespace xSignalRelay.Templating;

/// <summary>Плейсхолдери виду {key} у тілі шаблону. Ключ: літери/цифри/._-</summary>
public static partial class PlaceholderParser
{
    [GeneratedRegex(@"\{([a-zA-Z0-9_.\-]+)\}")]
    private static partial Regex Pattern();

    /// <summary>Унікальні імена плейсхолдерів у порядку появи.</summary>
    public static IReadOnlyList<string> Names(string body) =>
        Pattern().Matches(body).Select(m => m.Groups[1].Value).Distinct().ToList();

    /// <summary>Підставляє значення; кидає <see cref="TemplateRenderException"/>, якщо якогось ключа бракує.</summary>
    public static string Render(string body, IReadOnlyDictionary<string, string>? values)
    {
        return Pattern().Replace(body, match =>
        {
            var key = match.Groups[1].Value;
            if (values is not null && values.TryGetValue(key, out var value))
                return value;
            throw new TemplateRenderException(key);
        });
    }
}

public sealed class TemplateRenderException(string key)
    : Exception($"Не задано значення для плейсхолдера '{{{key}}}'")
{
    public string Key { get; } = key;
}
