using Microsoft.EntityFrameworkCore;
using TX_Manager.Application.Common.Interfaces;
using TX_Manager.Domain.Entities;
using System.Reflection;

namespace TX_Manager.Infrastructure.Persistence;

public class AppDbContext : DbContext, IApplicationDbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
    {
    }

    public DbSet<User> Users => Set<User>();
    public DbSet<Post> Posts => Set<Post>();
    public DbSet<AuthToken> AuthTokens => Set<AuthToken>();
    public DbSet<AnalyticsData> AnalyticsData => Set<AnalyticsData>();
    public DbSet<UserStrategy> UserStrategies => Set<UserStrategy>();
    public DbSet<ContentSuggestion> ContentSuggestions => Set<ContentSuggestion>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        builder.ApplyConfigurationsFromAssembly(Assembly.GetExecutingAssembly());

        base.OnModelCreating(builder);
        
        // Basic configurations if not using separate EntityTypeConfiguration files
        builder.Entity<User>()
            .HasOne(u => u.AuthToken)
            .WithOne(t => t.User)
            .HasForeignKey<AuthToken>(t => t.UserId);
            
        builder.Entity<User>()
            .HasMany(u => u.Posts)
            .WithOne(p => p.User)
            .HasForeignKey(p => p.UserId);

        builder.Entity<User>()
            .HasMany(u => u.AnalyticsData)
            .WithOne(a => a.User)
            .HasForeignKey(a => a.UserId);
    }
}
