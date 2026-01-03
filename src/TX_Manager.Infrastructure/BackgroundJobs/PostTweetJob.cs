using System.Threading.Tasks;
using Hangfire;
using Microsoft.Extensions.Logging;
using TX_Manager.Application.Services;

namespace TX_Manager.Infrastructure.BackgroundJobs;

public class PostTweetJob
{
    private readonly IPostService _postService;
    private readonly ILogger<PostTweetJob> _logger;

    public PostTweetJob(IPostService postService, ILogger<PostTweetJob> logger)
    {
        _postService = postService;
        _logger = logger;
    }

    [AutomaticRetry(Attempts = 0)] // We handle retries internally or via next schedule
    public async Task ExecuteAsync()
    {
        _logger.LogInformation("Starting PostTweetJob...");
        await _postService.PublishScheduledPostsAsync();
        _logger.LogInformation("PostTweetJob finished.");
    }
}
