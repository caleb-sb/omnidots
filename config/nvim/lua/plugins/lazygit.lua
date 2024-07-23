vim.keymap.set("n", "<leader>lg", ":silent LazyGit<CR>")

return {
  "kdheepak/lazygit.nvim",
  -- optional for floating window border decoration
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
}
