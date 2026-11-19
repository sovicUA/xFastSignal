using System.Text;
using System.Text.RegularExpressions;

namespace xSignalRelay.Templating;

/// <summary>
/// Плейсхолдери виду {key} у тілі шаблону (ключ: літери/цифри/._-) і розмітка xBot (SignalTemplate):
/// **жирний**, ~~закреслений~~, ||спойлер||, `моно`, _курсив_ — у статичному тексті шаблону.
/// </summary>
public static partial class PlaceholderParser
{
    [GeneratedRegex(@"\{([a-zA-Z0-9_.\-]+)\}")]
    private static partial Regex Pattern();

    // Як у xBot SignalTemplate: "**" перевіряється раніше за односимвольні роздільники.
    private static readonly (string Delimiter, string Style)[] Delimiters =
    [
        ("**", "BOLD"),
        ("~~", "STRIKETHROUGH"),
        ("||", "SPOILER"),
        ("`", "MONOSPACE"),
        ("_", "ITALIC"),
    ];

    /// <summary>Унікальні імена плейсхолдерів у порядку появи.</summary>
    public static IReadOnlyList<string> Names(string body) =>
        Pattern().Matches(body).Select(m => m.Groups[1].Value).Distinct().ToList();

    /// <summary>Підставляє значення без розбору розмітки (текст як є).</summary>
    public static string Render(string body, IReadOnlyDictionary<string, string>? values)
    {
        return Pattern().Replace(body, match => Value(match.Groups[1].Value, values));
    }

    /// <summary>
    /// Текст повідомлення й textStyles для signal-cli ("start:length:STYLE", офсети в UTF-16 code units —
    /// .NET string.Length рахує саме так). Розмітка розбирається лише в тексті шаблону: значення
    /// плейсхолдерів підставляються як звичайний текст (не можуть зламати розмітку, екранувати нічого не
    /// треба). Стилі не вкладаються: інший роздільник усередині відкритого — звичайний текст; незакритий
    /// роздільник лишається в тексті як є (старі шаблони з одиночним "_" чи "`" не ламаються).
    /// Кидає <see cref="TemplateRenderException"/>, якщо якогось ключа бракує.
    /// </summary>
    public static (string Text, IReadOnlyList<string> Styles) RenderStyled(
        string body, IReadOnlyDictionary<string, string>? values)
    {
        var sb = new StringBuilder();
        var styles = new List<string>();
        (string Delimiter, string Style, int Start)? open = null;

        var i = 0;
        while (i < body.Length)
        {
            if (body[i] == '{')
            {
                var match = Pattern().Match(body, i);
                if (match.Success && match.Index == i)
                {
                    sb.Append(Value(match.Groups[1].Value, values));
                    i += match.Length;
                    continue;
                }
            }

            var delimiter = Delimiters.FirstOrDefault(d => MatchesAt(body, i, d.Delimiter));
            if (delimiter.Delimiter is not null)
            {
                if (open is { } current && current.Style == delimiter.Style)
                {
                    if (sb.Length > current.Start)
                        styles.Add($"{current.Start}:{sb.Length - current.Start}:{current.Style}");
                    open = null;
                    i += delimiter.Delimiter.Length;
                    continue;
                }
                if (open is null)
                {
                    open = (delimiter.Delimiter, delimiter.Style, sb.Length);
                    i += delimiter.Delimiter.Length;
                    continue;
                }
                // Інший роздільник уже відкрито — стилі не вкладаються, лишаємо як звичайний текст.
            }

            sb.Append(body[i]);
            i++;
        }

        // Незакритий роздільник — повертаємо в текст; стилі до нього не зсуваються (усі вони раніше).
        if (open is { } unclosed)
            sb.Insert(unclosed.Start, unclosed.Delimiter);

        return (sb.ToString(), styles);
    }

    private static bool MatchesAt(string s, int i, string delimiter) =>
        i + delimiter.Length <= s.Length && string.CompareOrdinal(s, i, delimiter, 0, delimiter.Length) == 0;

    private static string Value(string key, IReadOnlyDictionary<string, string>? values) =>
        values is not null && values.TryGetValue(key, out var value) ? value : throw new TemplateRenderException(key);
}

public sealed class TemplateRenderException(string key)
    : Exception($"Не задано значення для плейсхолдера '{{{key}}}'")
{
    public string Key { get; } = key;
}
