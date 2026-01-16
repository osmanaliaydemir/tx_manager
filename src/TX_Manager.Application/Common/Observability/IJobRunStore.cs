using TX_Manager.Application.Common.Models;

namespace TX_Manager.Application.Common.Observability;

public interface IJobRunStore
{
    void SetLastPublishRun(PublishRunResult result);
    PublishRunResult? GetLastPublishRun();
}

