using System;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using TX_Manager.Application.DTOs;
using TX_Manager.Application.Services;

using TX_Manager.Domain.Enums;

namespace TX_Manager.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class PostsController : ControllerBase
{
    private readonly IPostService _postService;

    public PostsController(IPostService postService)
    {
        _postService = postService;
    }

    [HttpPost]
    public async Task<IActionResult> Create(CreatePostDto dto)
    {
        var result = await _postService.CreatePostAsync(dto);
        return CreatedAtAction(nameof(Get), new { id = result.Id }, result);
    }

    [HttpGet]
    public async Task<IActionResult> Get([FromQuery] Guid userId, [FromQuery] PostStatus? status)
    {
        var posts = await _postService.GetPostsAsync(userId, status);
        return Ok(posts);
    }
}
