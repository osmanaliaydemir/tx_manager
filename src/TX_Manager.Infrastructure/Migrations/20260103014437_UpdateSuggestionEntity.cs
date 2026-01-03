using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace TX_Manager.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class UpdateSuggestionEntity : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "IsAccepted",
                table: "ContentSuggestions");

            migrationBuilder.DropColumn(
                name: "IsRejected",
                table: "ContentSuggestions");

            migrationBuilder.RenameColumn(
                name: "RiskScore",
                table: "ContentSuggestions",
                newName: "Status");

            migrationBuilder.RenameColumn(
                name: "Content",
                table: "ContentSuggestions",
                newName: "SuggestedText");

            migrationBuilder.AlterColumn<string>(
                name: "EstimatedImpact",
                table: "ContentSuggestions",
                type: "nvarchar(max)",
                nullable: false,
                oldClrType: typeof(double),
                oldType: "float");

            migrationBuilder.AddColumn<DateTime>(
                name: "GeneratedAt",
                table: "ContentSuggestions",
                type: "datetime2",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddColumn<string>(
                name: "RiskAssessment",
                table: "ContentSuggestions",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "GeneratedAt",
                table: "ContentSuggestions");

            migrationBuilder.DropColumn(
                name: "RiskAssessment",
                table: "ContentSuggestions");

            migrationBuilder.RenameColumn(
                name: "SuggestedText",
                table: "ContentSuggestions",
                newName: "Content");

            migrationBuilder.RenameColumn(
                name: "Status",
                table: "ContentSuggestions",
                newName: "RiskScore");

            migrationBuilder.AlterColumn<double>(
                name: "EstimatedImpact",
                table: "ContentSuggestions",
                type: "float",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)");

            migrationBuilder.AddColumn<bool>(
                name: "IsAccepted",
                table: "ContentSuggestions",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "IsRejected",
                table: "ContentSuggestions",
                type: "bit",
                nullable: false,
                defaultValue: false);
        }
    }
}
