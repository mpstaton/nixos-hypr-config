# home/mps/dev-tools.nix
#
# CLI tools for working in the lossless-monorepo tree that were NOT already
# installed. Home-Manager rather than a devshell: these are wanted in every
# shell, permanently, not conditionally inside `nix develop`.
#
# The list is deliberately short. Most of what the monorepo's flake once tried
# to provide — ripgrep, fd, fzf, bat, eza, git, gh, jq, tmux, htop, starship,
# tree — is already installed (some here in home.nix, some system-wide), and
# re-declaring it per project only slowed every shell entry down. These four
# were the genuine gaps, plus direnv.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    delta # side-by-side git diffs, wired into git config below
    aha   # ANSI -> HTML: turns terminal output into a shareable page
    duf   # friendlier df
    yq    # jq for YAML — frontmatter is YAML across the whole content tree

    # Two greps, kept together because the choice between them is the point.
    #
    # ripgrep is the everyday one: fast, respects .gitignore by default, which
    # is what you want in a tree carrying node_modules and dist/ everywhere.
    # Moved here from home.nix so the search tooling is declared in one place.
    #
    # ugrep is the one for when ripgrep's defaults are the problem — it does
    # boolean queries (`-%` AND/OR/NOT), fuzzy matching (`-Z`), searches inside
    # archives and PDFs, and has an interactive TUI (`ug --query`). Slower and
    # more to remember; reach for it when a search is a question rather than a
    # pattern.
    ripgrep
    ugrep

    # ---- JS runtimes the sites' own scripts invoke ---------------------
    #
    # These were briefly put in the lossless-monorepo devshell instead, which
    # was wrong: `pnpm build` in mpstaton-site runs `bun scripts/fetch-*.ts`,
    # so a plain shell in that directory needs bun on PATH. Requiring a
    # devshell (or a direnv hook that is not yet active) to run the project's
    # own build script is friction with no upside — the build command should
    # just work.
    #
    # bun: mpstaton-site's fetch-context-v / fetch-essays / fetch-playlists.
    # deno: `jsr publish` is deno underneath, and the jsr CLI's own downloaded
    #       binary cannot execute on NixOS. No site RUNS on deno.
    bun
    deno

    # ---- Process and port inspection -----------------------------------
    #
    # These are here because their absence fails SILENTLY, which is the worst
    # way for a tool to be missing. A script asks for the PID holding a port,
    # gets nothing, carries on, and Astro's preview server then quietly
    # auto-increments onto a different port — so a comparison harness serves
    # the wrong build under the right label. That happened twice in one
    # session before anyone noticed the cause was `lsof: command not found`.
    #
    # Practically every script written by anyone (or anything) assumes at
    # least one of lsof/fuser exists.
    lsof
    psmisc # fuser, killall, pstree

    # ---- Small utilities that get reached for by reflex ----------------
    #
    # Each of these is a few hundred KB and is the obvious tool for a job that
    # comes up often enough. The cost of having them is nil; the cost of NOT
    # having them is a detour every time.
    sqlite   # reading a .db without writing a program
    zip      # unzip is already present; the other half was not
    dnsutils # dig — DNS debugging, incl. the custom-domain cutovers
    unixtools.xxd # hexdump for when a file is "corrupted" or has a BOM
    file     # what IS this thing
    entr     # rerun a command when files change
    just     # task runner; a Justfile beats a pile of shell scripts
  ];

  # direnv HAS to be installed permanently rather than shipped inside a
  # devshell: it must already be on PATH when you `cd` into a directory, or it
  # can never auto-load anything. With it here, an `.envrc` containing
  # `use flake .#js` gives you node/pnpm/bun/deno on entering the repo, and
  # `nix develop` stops needing to be typed at all.
  #
  # nix-direnv makes that fast and keeps the shell from being garbage-collected
  # between uses.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # delta is only useful if git actually calls it.
  #
  # `programs.git.delta.enable` was renamed to `programs.delta.enable`, and the
  # git wiring that used to happen implicitly now has to be asked for — both
  # warned on the last switch. Stating them explicitly is what the deprecation
  # is asking for, and it makes the two-part setup visible: install the pager,
  # then tell git to use it.
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };
}
