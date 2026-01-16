using System.Threading.Tasks;
using Hangfire;
using Microsoft.Extensions.Logging;
using TX_Manager.Application.Common.Observability;
using TX_Manager.Application.Services;

namespace TX_Manager.Infrastructure.BackgroundJobs;

public class PostTweetJob
{
    private readonly IPostService _postService;
    private readonly ILogger<PostTweetJob> _logger;
    private readonly IJobRunStore _store;

    public PostTweetJob(IPostService postService, ILogger<PostTweetJob> logger, IJobRunStore store)
    {
        _postService = postService;
        _logger = logger;
        _store = store;
    }

    [AutomaticRetry(Attempts = 0)] // We handle retries internally or via next schedule
    [DisableConcurrentExecution(timeoutInSeconds: 300)]
    public async Task ExecuteAsync()
    {
        _logger.LogInformation("Starting PostTweetJob...");
        var result = await _postService.PublishScheduledPostsAsync();
        _store.SetLastPublishRun(result);
        _logger.LogInformation("PostTweetJob finished.");
    }
}
