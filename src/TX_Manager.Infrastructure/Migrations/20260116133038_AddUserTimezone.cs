using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace TX_Manager.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddUserTimezone : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "TimeZoneName",
                table: "Users",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "TimeZoneOffsetMinutes",
                table: "Users",
                type: "int",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "TimeZoneName",
                table: "Users");

            migrationBuilder.DropColumn(
                name: "TimeZoneOffsetMinutes",
                table: "Users");
        }
    }
}
