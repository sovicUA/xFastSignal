using Microsoft.EntityFrameworkCore;

namespace xSignalRelay.Data;

public sealed class RelayDbContext(DbContextOptions<RelayDbContext> options) : DbContext(options)
{
    public DbSet<Template> Templates => Set<Template>();
    public DbSet<Recipient> Recipients => Set<Recipient>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Recipient>().Property(r => r.Kind).HasConversion<string>();
    }
}
