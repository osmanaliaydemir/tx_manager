using System;
using TX_Manager.Application.Common.Models;
using TX_Manager.Application.Common.Observability;

namespace TX_Manager.Api.Observability;

public class InMemoryJobRunStore : IJobRunStore
{
    private readonly object _lock = new();
    private PublishRunResult? _last;

    public void SetLastPublishRun(PublishRunResult result)
    {
        lock (_lock)
        {
            _last = result;
        }
    }

    public PublishRunResult? GetLastPublishRun()
    {
        lock (_lock)
        {
            return _last;
        }
    }
}

