-- mugdad's LazyVim tweaks: gruvbox + web dev (php/html/css/js) + bash + C

return {
  -- gruvbox everywhere
  { "ellisonleao/gruvbox.nvim" },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "gruvbox",
    },
  },

  -- language extras that exist upstream

  -- treesitter parsers for everything we touch
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      vim.list_extend(opts.ensure_installed, {
        "bash",
        "c",
        "css",
        "html",
        "javascript",
        "json",
        "lua",
        "markdown",
        "markdown_inline",
        "php",
        "query",
        "regex",
        "tsx",
        "typescript",
        "yaml",
      })
    end,
  },

  -- LSP servers installed system-wide via nix (see packages/dev.nix).
  -- mason = false tells LazyVim to use the PATH binary instead of waiting
  -- for a Mason download - works offline, no network flakiness.
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        intelephense = { mason = false }, -- PHP
        html = { mason = false },
        cssls = { mason = false },
        bashls = { mason = false }, -- bash / sh
        clangd = { mason = false }, -- C (OS course)
        vtsls = { mason = false }, -- JS / TS
        ts_ls = { mason = false }, -- fallback TS server
      },
    },
  },

  -- mason tools to pre-install
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "stylua",
        "shellcheck",
        "shfmt",
        "prettierd",
      },
    },
  },
}
