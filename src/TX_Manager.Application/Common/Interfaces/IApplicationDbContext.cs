using Microsoft.EntityFrameworkCore;
using TX_Manager.Domain.Entities;
using System.Threading;
using System.Threading.Tasks;

namespace TX_Manager.Application.Common.Interfaces;

public interface IApplicationDbContext
{
    DbSet<User> Users { get; }
    DbSet<Post> Posts { get; }
    DbSet<AuthToken> AuthTokens { get; }
    DbSet<AnalyticsData> AnalyticsData { get; }
    DbSet<UserStrategy> UserStrategies { get; }
    DbSet<ContentSuggestion> ContentSuggestions { get; }
    
    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
