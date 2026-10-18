-- LSP + formatting for Python.
-- mason installs the server binaries (pyright for types/completion, ruff for
-- lint/format); nvim-lspconfig only supplies each server's default config.
-- Servers are switched on with Neovim's own vim.lsp.enable() (0.11+), not the
-- old require("lspconfig").xxx.setup{} — that path is deprecated.
-- Built-in LSP keys (0.11+): K hover, grn rename, gra code action,
-- grr references, gri implementation, gO document symbols, [d / ]d diagnostics.
return {
  { "mason-org/mason.nvim", opts = {} },
  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = { "mason-org/mason.nvim", "neovim/nvim-lspconfig", "hrsh7th/cmp-nvim-lsp" },
    config = function()
      -- Advertise nvim-cmp's completion capabilities to every server.
      vim.lsp.config("*", { capabilities = require("cmp_nvim_lsp").default_capabilities() })
      require("mason-lspconfig").setup({
        ensure_installed = { "pyright", "ruff" },
        automatic_enable = false, -- enable explicitly below, so the list is visible here
      })
      vim.lsp.enable({ "pyright", "ruff" })
    end,
  },
  {
    -- Format on save: AI-written code gets normalized the moment it's saved.
    "stevearc/conform.nvim",
    event = "BufWritePre",
    opts = {
      formatters_by_ft = { python = { "ruff_format" } },
      format_on_save = { timeout_ms = 1000, lsp_format = "fallback" },
    },
  },
}
