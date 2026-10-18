local opt = vim.opt

vim.g.mapleader = " "
vim.g.maplocalleader = " "

opt.number = true
opt.relativenumber = true
opt.signcolumn = "yes"
opt.wrap = false
opt.scrolloff = 8
opt.cursorline = true

opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true
-- Python files still get 4-space indents from Neovim's built-in ftplugin.

opt.ignorecase = true
opt.smartcase = true

opt.splitright = true
opt.splitbelow = true

opt.undofile = true
opt.swapfile = false

opt.termguicolors = true
opt.updatetime = 250 -- faster diagnostics / CursorHold
opt.clipboard = "unnamedplus"
