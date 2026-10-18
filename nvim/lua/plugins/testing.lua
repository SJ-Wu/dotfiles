-- Run pytest from the editor right after Claude Code changes something.
return {
  "nvim-neotest/neotest",
  dependencies = {
    "nvim-neotest/nvim-nio",
    "nvim-lua/plenary.nvim",
    "nvim-neotest/neotest-python",
    "nvim-treesitter/nvim-treesitter", -- neotest-python needs the python parser
  },
  config = function()
    require("neotest").setup({
      adapters = { require("neotest-python")({ runner = "pytest" }) },
    })
  end,
  keys = {
    { "<leader>tt", function() require("neotest").run.run() end, desc = "Test nearest" },
    { "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Test file" },
    { "<leader>ts", function() require("neotest").summary.toggle() end, desc = "Test summary" },
    { "<leader>to", function() require("neotest").output.open({ enter = true }) end, desc = "Test output" },
  },
}
