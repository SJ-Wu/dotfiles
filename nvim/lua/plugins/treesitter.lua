-- Treesitter parsers. Neovim 0.12 only bundles c, lua, markdown, query, vim
-- and vimdoc — not python — and neotest-python needs the python parser to find
-- tests, so nvim-treesitter (main branch) installs it. Needs tree-sitter-cli
-- and a C compiler (Brewfile / Xcode CLT).
local parsers = { "python", "bash", "json", "toml", "yaml" }

return {
  "nvim-treesitter/nvim-treesitter",
  lazy = false, -- the plugin does not support lazy-loading
  build = ":TSUpdate",
  config = function()
    require("nvim-treesitter").install(parsers)
    vim.api.nvim_create_autocmd("FileType", {
      pattern = { "python", "sh", "bash", "json", "toml", "yaml" },
      callback = function() pcall(vim.treesitter.start) end,
    })
  end,
}
