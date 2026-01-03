using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace TX_Manager.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddStrategyEntities : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "ContentSuggestions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Content = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    Rationale = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    RiskScore = table.Column<int>(type: "int", nullable: false),
                    EstimatedImpact = table.Column<double>(type: "float", nullable: false),
                    IsAccepted = table.Column<bool>(type: "bit", nullable: false),
                    IsRejected = table.Column<bool>(type: "bit", nullable: false),
                    RejectionReason = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    ScheduledPostId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ContentSuggestions", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ContentSuggestions_Posts_ScheduledPostId",
                        column: x => x.ScheduledPostId,
                        principalTable: "Posts",
                        principalColumn: "Id");
                    table.ForeignKey(
                        name: "FK_ContentSuggestions_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "UserStrategies",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    PrimaryGoal = table.Column<int>(type: "int", nullable: false),
                    Tone = table.Column<int>(type: "int", nullable: false),
                    ForbiddenTopics = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    Language = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    PostsPerDay = table.Column<int>(type: "int", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserStrategies", x => x.Id);
                    table.ForeignKey(
                        name: "FK_UserStrategies_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_ContentSuggestions_ScheduledPostId",
                table: "ContentSuggestions",
                column: "ScheduledPostId");

            migrationBuilder.CreateIndex(
                name: "IX_ContentSuggestions_UserId",
                table: "ContentSuggestions",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_UserStrategies_UserId",
                table: "UserStrategies",
                column: "UserId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ContentSuggestions");

            migrationBuilder.DropTable(
                name: "UserStrategies");
        }
    }
}
