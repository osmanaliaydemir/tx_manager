using FluentValidation;
using TX_Manager.Application.DTOs;

namespace TX_Manager.Application.Validators;

public class CreatePostDtoValidator : AbstractValidator<CreatePostDto>
{
    public CreatePostDtoValidator()
    {
        RuleFor(x => x.Content)
            .NotEmpty().WithMessage("Content is required")
            .MaximumLength(280).WithMessage("Content must not exceed 280 characters"); // X limit
            
        RuleFor(x => x.UserId).NotEmpty();
        
        RuleFor(x => x.ScheduledFor)
            .Must(date => date == null || date > System.DateTime.UtcNow)
            .WithMessage("Scheduled time must be in the future");
    }
}
