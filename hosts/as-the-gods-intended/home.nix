# as-the-gods-intended — user environment configuration.
# All user-facing tools and their settings are declared here.
# Edit this file and run `nrs` (or `sudo nixos-rebuild switch --flake /etc/nixos#as-the-gods-intended`) to apply changes.
# See README.md for a guide to making changes.
{ pkgs, ... }:
{
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  # TODO: update "friend" to match the username set in default.nix.
  home-manager.users.friend = {

    home.username = "friend";
    home.homeDirectory = "/home/friend";
    home.stateVersion = "25.11";

    # ── zsh ─────────────────────────────────────────────────────────────────
    programs.zsh = {
      enable = true;
      history = {
        size = 10000;
        save = 10000;
        ignoreDups = true;
        ignoreSpace = true;
        share = true;
      };
      initContent = ''
        autoload -Uz compinit && compinit
        zstyle ':completion:*' menu select
        zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
      '';
      shellAliases = {
        # eza
        ls  = "eza --icons --group-directories-first";
        ll  = "eza --icons --group-directories-first -l";
        la  = "eza --icons --group-directories-first -la";
        lt  = "eza --icons --tree --level=2";
        # bat
        cat = "bat --paging=never";
        # navigation
        ".."  = "cd ..";
        "..." = "cd ../..";
        mkdir = "mkdir -p";
        # NixOS rebuild
        nrs = "sudo nixos-rebuild switch --flake /etc/nixos#as-the-gods-intended";
      };
      sessionVariables = {
        EDITOR = "hx";
        VISUAL = "hx";
      };
    };

    # ── fzf ─────────────────────────────────────────────────────────────────
    programs.fzf = {
      enable = true;
      enableZshIntegration = true;
    };

    # ── git ─────────────────────────────────────────────────────────────────
    # TODO: fill in name and email before first use.
    programs.git = {
      enable = true;
      # TODO: fill in name and email before first use.
      settings = {
        user.name   = "Your Name";
        user.email  = "you@example.com";
        core = {
          editor    = "hx";
          autocrlf  = "input";
          whitespace = "trailing-space,space-before-tab";
        };
        pull.rebase          = false;
        push.autoSetupRemote = true;
        init.defaultBranch   = "main";
        merge.conflictstyle  = "diff3";
        diff.colorMoved      = "default";
        alias = {
          st  = "status -sb";
          lg  = "log --oneline --graph --decorate";
          lga = "log --oneline --graph --decorate --all";
          undo = "reset --soft HEAD~1";
        };
      };
    };

    # ── tmux ────────────────────────────────────────────────────────────────
    programs.tmux = {
      enable = true;
      prefix        = "C-a";
      mouse         = true;
      historyLimit  = 10000;
      baseIndex     = 1;
      escapeTime    = 0;       # no delay after Escape — important for Helix
      terminal      = "tmux-256color";
      focusEvents   = true;
      extraConfig   = ''
        set -ga terminal-overrides ",xterm-256color:Tc"
        set -g renumber-windows on
        set -g pane-base-index 1

        # Reload config
        bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded"

        # Split panes with | and -
        bind | split-window -h -c "#{pane_current_path}"
        bind - split-window -v -c "#{pane_current_path}"
        unbind '"'
        unbind %

        # Navigate panes with vi-style keys
        bind h select-pane -L
        bind j select-pane -D
        bind k select-pane -U
        bind l select-pane -R

        # Status bar
        set -g status-position bottom
        set -g status-style 'bg=colour235 fg=colour255'
        set -g status-left '#[bold] #S '
        set -g status-right '#[fg=colour245] %H:%M %d-%b '
        set -g status-right-length 50
        set -g window-status-current-style 'bold fg=colour81'
      '';
    };

    # ── bat ─────────────────────────────────────────────────────────────────
    programs.bat = {
      enable = true;
      config = {
        theme        = "TwoDark";
        style        = "numbers,changes";
        italic-text  = "always";
      };
    };

    # ── btop ────────────────────────────────────────────────────────────────
    programs.btop = {
      enable = true;
      settings = {
        color_theme   = "Default";
        update_ms     = 2000;
        shown_boxes   = "cpu mem net proc";
        clock_format  = "%H:%M";
        check_temp    = true;
        proc_sorting  = "cpu lazy";
        proc_reversed = false;
        proc_tree     = false;
      };
    };

    # ── fastfetch ───────────────────────────────────────────────────────────
    programs.fastfetch = {
      enable = true;
      settings = {
        logo.type        = "auto";
        display.separator = "  ";
        modules = [
          "title"
          "separator"
          "os"
          "kernel"
          "uptime"
          "packages"
          "shell"
          "terminal"
          "separator"
          "cpu"
          "memory"
          "disk"
          "separator"
          "colors"
        ];
      };
    };

    # ── helix ───────────────────────────────────────────────────────────────
    # If you already have a Helix config you prefer, replace the values below.
    # All Helix settings: https://docs.helix-editor.com/configuration.html
    programs.helix = {
      enable = true;
      settings = {
        theme = "catppuccin_mocha";
        editor = {
          line-number            = "relative";
          cursorline             = true;
          auto-save              = true;
          completion-trigger-len = 1;
          rulers                 = [ 80 120 ];
          cursor-shape = {
            insert = "bar";
            normal = "block";
            select = "underline";
          };
          file-picker.hidden = false;
          statusline = {
            left   = [ "mode" "spinner" "file-name" ];
            center = [ ];
            right  = [ "diagnostics" "selections" "position" "file-encoding" ];
          };
          indent-guides = {
            render    = true;
            character = "╎";
          };
        };
      };
      languages = {
        language = [
          {
            name      = "nix";
            formatter = { command = "nixfmt"; };
          }
        ];
      };
    };
  };
}
