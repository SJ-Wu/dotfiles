-- yazi in a floating window; `nvim some/dir` opens yazi instead of netrw.
return {
  "mikavilpas/yazi.nvim",
  event = "VeryLazy",
  dependencies = { "nvim-lua/plenary.nvim" },
  keys = {
    { "<leader>-", "<cmd>Yazi<cr>", desc = "Yazi at current file" },
    { "<leader>cw", "<cmd>Yazi cwd<cr>", desc = "Yazi in working directory" },
  },
  opts = { open_for_directories = true },
  init = function()
    vim.g.loaded_netrwPlugin = 1 -- let yazi handle directories
  end,
}
