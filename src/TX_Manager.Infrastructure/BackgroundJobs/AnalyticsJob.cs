using System.Threading.Tasks;
using Hangfire;
using Microsoft.Extensions.Logging;
using TX_Manager.Application.Services;

namespace TX_Manager.Infrastructure.BackgroundJobs;

public class AnalyticsJob
{
    private readonly IAnalyticsService _analyticsService;
    private readonly ILogger<AnalyticsJob> _logger;

    public AnalyticsJob(IAnalyticsService analyticsService, ILogger<AnalyticsJob> logger)
    {
        _analyticsService = analyticsService;
        _logger = logger;
    }

    [AutomaticRetry(Attempts = 0)]
    public async Task ExecuteAsync()
    {
        _logger.LogInformation("Starting AnalyticsJob...");
        await _analyticsService.UpdateMetricsForRecentPostsAsync();
        _logger.LogInformation("AnalyticsJob finished.");
    }
}
