using System;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TX_Manager.Api.Auth;
using TX_Manager.Application.DTOs;
using TX_Manager.Application.Services;

using TX_Manager.Domain.Enums;

namespace TX_Manager.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
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
        dto.UserId = User.GetUserId();
        var result = await _postService.CreatePostAsync(dto);
        return CreatedAtAction(nameof(Get), new { id = result.Id }, result);
    }

    [HttpPost("thread")]
    public async Task<IActionResult> CreateThread([FromBody] CreateThreadDto dto)
    {
        dto.UserId = User.GetUserId();
        var results = await _postService.CreateThreadAsync(dto);
        return Ok(results);
    }

    [HttpGet]
    public async Task<IActionResult> Get([FromQuery] PostStatus? status)
    {
        var userId = User.GetUserId();
        var posts = await _postService.GetPostsAsync(userId, status);
        return Ok(posts);
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetById(Guid id)
    {
        try
        {
            var post = await _postService.GetPostByIdAsync(User.GetUserId(), id);
            return Ok(post);
        }
        catch (KeyNotFoundException)
        {
            return NotFound();
        }
    }

    public class UpdatePostRequest
    {
        public string Content { get; set; }
        public DateTime? ScheduledFor { get; set; }
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> Update(Guid id, [FromBody] UpdatePostRequest request)
    {
        try 
        {
             var result = await _postService.UpdatePostAsync(User.GetUserId(), id, request.Content, request.ScheduledFor);
             return Ok(result);
        } 
        catch (KeyNotFoundException) { return NotFound(); }
        catch (InvalidOperationException e) { return BadRequest(e.Message); }
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(Guid id)
    {
        try 
        {
            await _postService.DeletePostAsync(User.GetUserId(), id);
            return NoContent();
        } 
        catch (KeyNotFoundException) { return NotFound(); }
    }

    [HttpPost("{id}/cancel")]
    public async Task<IActionResult> Cancel(Guid id)
    {
        try
        {
            await _postService.CancelScheduleAsync(User.GetUserId(), id);
            return Ok();
        }
        catch (KeyNotFoundException) { return NotFound(); }
        catch (InvalidOperationException e) { return BadRequest(e.Message); }
    }
}
