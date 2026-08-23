{
  inputs,
  pkgs,
  ...
}: {
  imports = [inputs.nixvim.homeModules.nixvim];

  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    vimdiffAlias = true;

    # nixvim evaluates against its own pinned nixpkgs (flake input has no
    # follows), so the host-wide allowUnfree doesn't reach it. intelephense
    # needs this.
    nixpkgs.config.allowUnfree = true;

    globals = {
      mapleader = " ";
      maplocalleader = " ";
    };

    # system clipboard via wayland
    clipboard = {
      register = "unnamedplus";
      providers.wl-copy.enable = true;
    };

    opts = {
      number = true;
      relativenumber = true;
      mouse = "a";
      breakindent = true;
      undofile = true;
      ignorecase = true;
      smartcase = true;
      signcolumn = "yes";
      updatetime = 250;
      timeoutlen = 400;
      completeopt = ["menu" "menuone" "noselect"];
      tabstop = 2;
      shiftwidth = 2;
      expandtab = true;
      smartindent = true;
      scrolloff = 8;
      cursorline = true;
      termguicolors = true;
    };

    colorschemes.gruvbox = {
      enable = true;
      settings = {
        contrast = "hard";
        transparent_bg = false;
      };
    };

    keymaps = [
      # clear search highlight
      {
        mode = "n";
        key = "<Esc>";
        action = "<cmd>nohlsearch<CR>";
      }
      # window navigation
      {
        mode = "n";
        key = "<C-h>";
        action = "<C-w>h";
      }
      {
        mode = "n";
        key = "<C-j>";
        action = "<C-w>j";
      }
      {
        mode = "n";
        key = "<C-k>";
        action = "<C-w>k";
      }
      {
        mode = "n";
        key = "<C-l>";
        action = "<C-w>l";
      }
      # resize with arrows
      {
        mode = "n";
        key = "<Up>";
        action = "<cmd>resize +2<CR>";
      }
      {
        mode = "n";
        key = "<Down>";
        action = "<cmd>resize -2<CR>";
      }
      {
        mode = "n";
        key = "<Left>";
        action = "<cmd>vertical resize -2<CR>";
      }
      {
        mode = "n";
        key = "<Right>";
        action = "<cmd>vertical resize +2<CR>";
      }
      # save / quit
      {
        mode = "n";
        key = "<leader>w";
        action = "<cmd>w<cr>";
        options.desc = "Save";
      }
      {
        mode = "n";
        key = "<leader>q";
        action = "<cmd>q<cr>";
        options.desc = "Quit";
      }
      # file explorer
      {
        mode = "n";
        key = "<leader>e";
        action = "<cmd>Neotree toggle<cr>";
        options.desc = "File explorer";
      }
      # telescope
      {
        mode = "n";
        key = "<leader>ff";
        action = "<cmd>Telescope find_files<cr>";
        options.desc = "Find files";
      }
      {
        mode = "n";
        key = "<leader>fg";
        action = "<cmd>Telescope live_grep<cr>";
        options.desc = "Grep";
      }
      {
        mode = "n";
        key = "<leader>fb";
        action = "<cmd>Telescope buffers<cr>";
        options.desc = "Buffers";
      }
      {
        mode = "n";
        key = "<leader>fh";
        action = "<cmd>Telescope help_tags<cr>";
        options.desc = "Help";
      }
      # terminal
      {
        mode = "n";
        key = "<leader>t";
        action = "<cmd>ToggleTerm direction=horizontal<cr>";
        options.desc = "Terminal";
      }
      # LSP (gd/gr/K/<leader>rn/<leader>ca come from nixvim's lsp defaults)
      {
        mode = "n";
        key = "]d";
        action = "<cmd>lua vim.diagnostic.jump({count=1, float=true})<cr>";
        options.desc = "Next diagnostic";
      }
      {
        mode = "n";
        key = "[d";
        action = "<cmd>lua vim.diagnostic.jump({count=-1, float=true})<cr>";
        options.desc = "Prev diagnostic";
      }
    ];

    plugins = {
      # new LSP plugin layer; servers configured via top-level `lsp` below.
      # the legacy plugins.lsp module is deprecated upstream.
      lspconfig.enable = true;

      web-devicons.enable = true;

      which-key.enable = true;

      lualine.enable = true;

      neo-tree.enable = true;

      telescope.enable = true;

      treesitter.enable = true; # installs all grammars via nix

      blink-cmp = {
        enable = true;
        settings = {
          sources.default = ["lsp" "path" "snippets" "buffer"];
          keymap.preset = "super-tab";
          completion.documentation.auto_show = true;
        };
      };
      friendly-snippets.enable = true;

      nvim-autopairs.enable = true;
      comment.enable = true;
      gitsigns.enable = true;
      toggleterm.enable = true;

      conform-nvim = {
        enable = true;
        settings = {
          format_on_save = {
            lsp_format = "fallback";
            timeout_ms = 500;
          };
          formatters_by_ft = {
            javascript = ["prettierd"];
            javascriptreact = ["prettierd"];
            typescript = ["prettierd"];
            typescriptreact = ["prettierd"];
            html = ["prettierd"];
            css = ["prettierd"];
            scss = ["prettierd"];
            json = ["prettierd"];
            bash = ["shfmt"];
            sh = ["shfmt"];
            c = ["clang-format"];
            lua = ["stylua"];
          };
        };
      };
    };

    # LSP servers for: web dev (js/ts, html, css, tailwind, emmet), php,
    # shell scripting and C (OS course). Servers are installed by nixvim
    # itself - never use Mason on NixOS. gd/gr/K/rename/code-action keymaps
    # are generated by the lsp module defaults. (No top-level lsp.enable in
    # current nixvim: enabling a server activates LSP.)
    lsp = {
      servers = {
        ts_ls.enable = true;
        html.enable = true;
        cssls.enable = true;
        tailwindcss.enable = true;
        emmet_language_server.enable = true;
        bashls.enable = true;
        clangd.enable = true;
        intelephense.enable = true; # PHP
        lua_ls.enable = true;
        jsonls.enable = true;
      };
    };

    extraPackages = with pkgs; [
      clang-tools
      prettierd
      shfmt
      stylua
      nodejs
      shellcheck
    ];
  };
}
