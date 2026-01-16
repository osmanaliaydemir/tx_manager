using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace TX_Manager.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddPostFailureCode : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "FailureCode",
                table: "Posts",
                type: "nvarchar(max)",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "FailureCode",
                table: "Posts");
        }
    }
}
