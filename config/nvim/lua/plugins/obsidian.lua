local vault = vim.fn.expand("~/Documents/obsidian-sync")

return {
  "obsidian-nvim/obsidian.nvim",
  version = "*", -- recommended, use latest release instead of latest commit
  -- Only load for markdown files inside the vault, or when asked for directly.
  event = {
    "BufReadPre " .. vault .. "/**.md",
    "BufNewFile " .. vault .. "/**.md",
  },
  cmd = "Obsidian",
  keys = {
    { "<leader>od", "<cmd>Obsidian today<cr>", desc = "Obsidian daily note" },
  },
  opts = {
    legacy_commands = false,
    workspaces = {
      {
        name = "personal",
        path = vault,
      },
    },
    daily_notes = {
      folder = "daily",
    },
  },
}
