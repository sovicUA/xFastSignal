namespace xSignalRelay.Data;

/// <summary>
/// Одноразове наповнення БД з секції "Seed" конфігурації (лише коли "Seed:Enabled" = true
/// і відповідна таблиця порожня). Тимчасовий засіб, поки немає admin-CRUD ендпоінтів.
/// </summary>
public static class DbSeeder
{
    public static void Seed(RelayDbContext db, IConfiguration config, ILogger logger)
    {
        if (!config.GetValue("Seed:Enabled", false))
            return;

        if (!db.Templates.Any())
        {
            var templates = config.GetSection("Seed:Templates").Get<List<Template>>() ?? [];
            db.Templates.AddRange(templates);
        }

        if (!db.Recipients.Any())
        {
            var recipients = config.GetSection("Seed:Recipients").Get<List<Recipient>>() ?? [];
            db.Recipients.AddRange(recipients);
        }

        if (db.ChangeTracker.HasChanges())
        {
            db.SaveChanges();
            logger.LogInformation("DbSeeder: базові шаблони/одержувачі додано з конфігурації");
        }
    }
}
