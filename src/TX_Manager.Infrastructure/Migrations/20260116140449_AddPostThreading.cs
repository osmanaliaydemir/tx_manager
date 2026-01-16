using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace TX_Manager.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddPostThreading : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "ThreadId",
                table: "Posts",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "ThreadIndex",
                table: "Posts",
                type: "int",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ThreadId",
                table: "Posts");

            migrationBuilder.DropColumn(
                name: "ThreadIndex",
                table: "Posts");
        }
    }
}
