{ inputs, lib, ... }:
let
  # =============================================================================
  # TOGGLE SWITCHES — set any to false to disable that entire category
  # =============================================================================
  dashboard  = true;  # Alpha — cool startup screen
  ui         = true;  # which-key, lualine, bufferline, noice, fidget, barbecue
  editing    = true;  # telescope, oil, autopairs, surround, comment, todo-comments
  coding     = true;  # LSP (auto-detect by filetype), treesitter, conform, blink-cmp
  git        = true;  # gitsigns, fugitive
  terminal   = true;  # toggleterm — floating terminal
  navigation = true;  # smart-splits, indent-blankline, neoscroll
  debug      = true;  # DAP — C/C++/Rust/Python/Go debugger
  tools      = true;  # undotree, colorizer, trouble, markdown-preview
in
{
  imports = [ inputs.nixvim.homeModules.nixvim ];

  programs.nixvim = {
    enable = true;
    vimAlias = true;
    viAlias = true;

    opts = {
      number = true;
      relativenumber = true;
      shiftwidth = 2;
      tabstop = 2;
      expandtab = true;
      mouse = "a";
      termguicolors = true;
      hidden = true;
      undofile = true;
      scrolloff = 8;
      signcolumn = "yes";
      updatetime = 250;
    };

    globals.mapleader = " ";

    colorschemes.gruvbox.enable = true;

    # =========================================================================
    # ALL PLUGINS — merged via mkMerge
    # =========================================================================
    plugins = lib.mkMerge [
      # ----- DASHBOARD -----
      (lib.mkIf dashboard {
        alpha = {
          enable = true;
          settings.layout = [
            { type = "padding"; val = 2; }
            {
              type = "text";
              val = [
                "  ███╗   ██╗██╗██╗  ██╗██╗   ██╗██╗███╗   ███╗"
                "  ████╗  ██║██║╚██╗██╔╝██║   ██║██║████╗ ████║"
                "  ██╔██╗ ██║██║ ╚██╔╝ ██║   ██║██║██╔████╔██║"
                "  ██║╚██╗██║██║ ██╔██╗ ╚██╗ ██╔╝██║██║╚██╔╝██║"
                "  ██║ ╚████║██║██╔╝ ██╗ ╚████╔╝ ██║██║ ╚═╝ ██║"
                "  ╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝  ╚═══╝  ╚═╝╚═╝     ╚═╝"
              ];
              opts = { hl = "GruvboxGreen"; position = "center"; };
            }
            { type = "padding"; val = 2; }
            {
              type = "group";
              val = [
                {
                  type = "button";
                  on_press.__raw = "function() require('telescope.builtin').find_files() end";
                  opts = { keymap = [ "n" "f" "" { nowait = true; } ]; position = "center"; shortcut = "f"; };
                  val = "    Find File";
                }
                {
                  type = "button";
                  on_press.__raw = "function() require('telescope.builtin').live_grep() end";
                  opts = { keymap = [ "n" "g" "" { nowait = true; } ]; position = "center"; shortcut = "g"; };
                  val = "    Grep Words";
                }
                {
                  type = "button";
                  on_press.__raw = "function() vim.cmd('enew') end";
                  opts = { keymap = [ "n" "n" "" { nowait = true; } ]; position = "center"; shortcut = "n"; };
                  val = "    New File";
                }
                {
                  type = "button";
                  on_press.__raw = "function() require('telescope.builtin').oldfiles() end";
                  opts = { keymap = [ "n" "r" "" { nowait = true; } ]; position = "center"; shortcut = "r"; };
                  val = "    Recent Files";
                }
                {
                  type = "button";
                  on_press.__raw = "function() vim.cmd('qa') end";
                  opts = { keymap = [ "n" "q" "" { nowait = true; } ]; position = "center"; shortcut = "q"; };
                  val = "    Quit";
                }
              ];
              opts = { spacing = 1; };
            }
            { type = "padding"; val = 2; }
            {
              type = "text";
              val = "    github.com/mugdad/nixos-config";
              opts = { hl = "GruvboxFg4"; position = "center"; };
            }
          ];
        };
      })
      # ----- UI -----
      (lib.mkIf ui {
        which-key.enable = true;
        lualine.enable = true;
        bufferline.enable = true;
        noice.enable = true;
        fidget.enable = true;
        barbecue.enable = true;
      })

      # ----- EDITING -----
      (lib.mkIf editing {
        telescope.enable = true;
        oil.enable = true;
        nvim-autopairs.enable = true;
        nvim-surround.enable = true;
        comment.enable = true;
        todo-comments.enable = true;
      })

      # ----- CODING -----
      (lib.mkIf coding {
        treesitter = {
          enable = true;
          settings = {
            auto_install = true;
            highlight.enable = true;
            indent.enable = true;
          };
        };

        lsp = {
          enable = true;
          servers = {
            nixd.enable = true;           # Nix
            rust_analyzer.enable = true;  # Rust
            ts_ls.enable = true;          # TypeScript/JavaScript
            pyright.enable = true;        # Python
            lua_ls.enable = true;         # Lua
            gopls.enable = true;          # Go
            clangd.enable = true;         # C/C++
            bashls.enable = true;         # Bash
            marksman.enable = true;       # Markdown
            jsonls.enable = true;         # JSON
            yamlls.enable = true;         # YAML
            html.enable = true;           # HTML
            cssls.enable = true;          # CSS
            dockerls.enable = true;       # Docker
            taplo.enable = true;          # TOML
            terraformls.enable = true;    # Terraform
          };
        };

        conform-nvim = {
          enable = true;
          settings = {
            formatters_by_ft = {
              nix = [ "nixfmt" ];
              python = [ "black" ];
              rust = [ "rustfmt" ];
              go = [ "gofmt" ];
              lua = [ "stylua" ];
              javascript = [ "prettierd" "prettier" ];
              typescript = [ "prettierd" "prettier" ];
              json = [ "prettierd" "prettier" ];
              yaml = [ "prettierd" "prettier" ];
              markdown = [ "prettierd" "prettier" ];
              html = [ "prettierd" "prettier" ];
              css = [ "prettierd" "prettier" ];
              terraform = [ "terraform_fmt" ];
              "*" = [ "trim_whitespace" ];
            };
            format_on_save = {
              lsp_fallback = true;
              timeout_ms = 1000;
            };
          };
        };

        blink-cmp = {
          enable = true;
          settings = {
            keymap.preset = "default";
            sources.default = [ "lsp" "snippets" "buffer" "path" ];
          };
        };
      })

      # ----- GIT -----
      (lib.mkIf git {
        gitsigns.enable = true;
        fugitive.enable = true;
      })

      # ----- TERMINAL -----
      (lib.mkIf terminal {
        toggleterm.enable = true;
      })

      # ----- NAVIGATION -----
      (lib.mkIf navigation {
        smart-splits.enable = true;
        indent-blankline.enable = true;
        neoscroll.enable = true;
      })

      # ----- DEBUG -----
      (lib.mkIf debug {
        dap.enable = true;
        dap-ui.enable = true;
        dap-virtual-text.enable = true;
      })

      # ----- TOOLS -----
      (lib.mkIf tools {
        undotree.enable = true;
        colorizer.enable = true;
        trouble.enable = true;
        markdown-preview.enable = true;
      })
    ];

    # =========================================================================
    # KEYMAPS
    # =========================================================================
    keymaps = [
      # ----- Telescope -----
      { key = "<leader>ff"; action = "<cmd>Telescope find_files<CR>"; }
      { key = "<leader>fg"; action = "<cmd>Telescope live_grep<CR>"; }
      { key = "<leader>fb"; action = "<cmd>Telescope buffers<CR>"; }
      { key = "<leader>fh"; action = "<cmd>Telescope help_tags<CR>"; }
      { key = "<leader>fs"; action = "<cmd>Telescope lsp_document_symbols<CR>"; }
      { key = "<leader>fd"; action = "<cmd>Telescope diagnostics<CR>"; }

      # ----- Oil / file browser -----
      { key = "<leader>o"; action = "<cmd>Oil<CR>"; }

      # ----- Terminal -----
      { key = "<leader>tt"; action = "<cmd>ToggleTerm<CR>"; }

      # ----- Trouble -----
      { key = "<leader>xx"; action = "<cmd>Trouble diagnostics toggle<CR>"; }

      # ----- Undotree -----
      { key = "<leader>u"; action = "<cmd>UndotreeToggle<CR>"; }

      # ----- LSP -----
      { key = "gd"; action = "<cmd>lua vim.lsp.buf.definition()<CR>"; }
      { key = "gD"; action = "<cmd>lua vim.lsp.buf.declaration()<CR>"; }
      { key = "gi"; action = "<cmd>lua vim.lsp.buf.implementation()<CR>"; }
      { key = "gr"; action = "<cmd>lua vim.lsp.buf.references()<CR>"; }
      { key = "K"; action = "<cmd>lua vim.lsp.buf.hover()<CR>"; }
      { key = "<leader>ca"; action = "<cmd>lua vim.lsp.buf.code_action()<CR>"; }
      { key = "<leader>rn"; action = "<cmd>lua vim.lsp.buf.rename()<CR>"; }
      { key = "[d"; action = "<cmd>lua vim.diagnostic.goto_next()<CR>"; }
      { key = "]d"; action = "<cmd>lua vim.diagnostic.goto_prev()<CR>"; }
      { key = "<leader>q"; action = "<cmd>lua vim.diagnostic.setloclist()<CR>"; }

      # ----- Markdown preview -----
      { key = "<leader>mp"; action = "<cmd>MarkdownPreview<CR>"; }

      # ----- Bufferline tabs -----
      { key = "<tab>"; action = "<cmd>BufferLineCycleNext<CR>"; }
      { key = "<S-tab>"; action = "<cmd>BufferLineCyclePrev<CR>"; }
      { key = "<leader>bd"; action = "<cmd>bd<CR>"; }
    ];
  };
}
