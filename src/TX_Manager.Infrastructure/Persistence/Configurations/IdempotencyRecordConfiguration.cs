using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using TX_Manager.Infrastructure.Persistence.Entities;

namespace TX_Manager.Infrastructure.Persistence.Configurations;

public class IdempotencyRecordConfiguration : IEntityTypeConfiguration<IdempotencyRecord>
{
    public void Configure(EntityTypeBuilder<IdempotencyRecord> builder)
    {
        builder.ToTable("IdempotencyRecords");

        builder.HasKey(x => x.Id);

        builder.Property(x => x.Key)
            .HasMaxLength(200)
            .IsRequired();

        builder.Property(x => x.Method)
            .HasMaxLength(16)
            .IsRequired();

        builder.Property(x => x.Path)
            .HasMaxLength(512)
            .IsRequired();

        builder.Property(x => x.ContentType)
            .HasMaxLength(128);

        builder.HasIndex(x => new { x.Key, x.Method, x.Path })
            .IsUnique();
    }
}

