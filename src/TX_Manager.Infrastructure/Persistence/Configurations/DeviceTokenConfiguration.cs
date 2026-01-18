using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using TX_Manager.Domain.Entities;

namespace TX_Manager.Infrastructure.Persistence.Configurations;

public class DeviceTokenConfiguration : IEntityTypeConfiguration<DeviceToken>
{
    public void Configure(EntityTypeBuilder<DeviceToken> builder)
    {
        builder.ToTable("DeviceTokens");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.Token)
            .IsRequired()
            .HasMaxLength(512);

        builder.Property(x => x.DeviceId)
            .HasMaxLength(128);

        builder.HasIndex(x => new { x.UserId, x.Token })
            .IsUnique();

        builder.HasIndex(x => x.Token);
    }
}

