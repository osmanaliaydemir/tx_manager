using System.Threading.Tasks;

namespace TX_Manager.Application.Services;

public interface IAnalyticsService
{
    Task UpdateMetricsForRecentPostsAsync();
}
