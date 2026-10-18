-- Moving and editing text.
return {
  {
    -- Jump anywhere on screen by typing two characters.
    "smoka7/hop.nvim",
    version = "*",
    opts = {},
    keys = {
      { "<leader>j", "<cmd>HopChar2<cr>", mode = { "n", "x", "o" }, desc = "Hop to 2 chars" },
    },
  },
  {
    -- ys{motion}{char} add, ds{char} delete, cs{old}{new} change surroundings.
    "kylechui/nvim-surround",
    version = "*",
    event = "VeryLazy",
    opts = {},
  },
  {
    -- s{motion} replaces text with the register; sx{motion} twice swaps two texts.
    "gbprod/substitute.nvim",
    opts = {},
    keys = {
      { "s", function() require("substitute").operator() end, desc = "Substitute" },
      { "ss", function() require("substitute").line() end, desc = "Substitute line" },
      { "S", function() require("substitute").eol() end, desc = "Substitute to EOL" },
      { "s", function() require("substitute").visual() end, mode = "x", desc = "Substitute" },
      { "sx", function() require("substitute.exchange").operator() end, desc = "Exchange" },
      { "sxx", function() require("substitute.exchange").line() end, desc = "Exchange line" },
    },
  },
}
