using Microsoft.AspNetCore.Mvc;
using TX_Manager.Application.Common.Observability;

namespace TX_Manager.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AdminController : ControllerBase
{
    private readonly IJobRunStore _store;

    public AdminController(IJobRunStore store)
    {
        _store = store;
    }

    [HttpGet("jobs/publish/last")]
    public IActionResult GetLastPublishRun()
    {
        var last = _store.GetLastPublishRun();
        if (last == null) return NoContent();
        return Ok(last);
    }
}

