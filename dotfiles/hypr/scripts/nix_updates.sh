#!/usr/bin/env bash
# Waybar module: is this system's pinned nixpkgs behind the nixos-26.05 branch?
# Emits one JSON line: {text, tooltip, class}.
#   class "has-updates" -> nixpkgs branch moved past our lock (updates available)
#   class "updated"     -> lock == branch HEAD (nothing to do)
#   (offline/error      -> empty text, module hides)
# `--open` instead opens a terminal with the update/preview commands.
FLAKE="$HOME/code/nixos-hypr-config"
BRANCH="nixos-26.05"
REPO="https://github.com/NixOS/nixpkgs.git"

if [ "${1:-}" = "--open" ]; then
    exec kitty --hold --title "NixOS update" -e bash -lc \
      "cd '$FLAKE'; echo; echo 'Preview what would change, then update:'; \
       echo '  nix flake update'; \
       echo '  nixos-rebuild build --flake .#hypr-nix && nix store diff-closures /run/current-system ./result'; \
       echo '  sudo nixos-rebuild switch --flake .#hypr-nix'; echo; exec bash"
fi

emit() { printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$1" "$2" "$3"; }

locked=$(jq -r '.nodes.nixpkgs.locked.rev // empty' "$FLAKE/flake.lock" 2>/dev/null)
[ -z "$locked" ] && { emit "" "nixpkgs rev not found in flake.lock" "error"; exit 0; }

remote=$(GIT_TERMINAL_PROMPT=0 timeout 8 git ls-remote "$REPO" "$BRANCH" 2>/dev/null | awk 'NR==1{print $1}')
[ -z "$remote" ] && { emit "" "NixOS: offline — can't check $BRANCH" "offline"; exit 0; }

if [ "$locked" = "$remote" ]; then
    emit "󰄬" "NixOS up to date ($BRANCH)" "updated"
    exit 0
fi

# best-effort commit count (unauthenticated GitHub compare API; may be rate-limited)
n=$(curl -sf --max-time 8 "https://api.github.com/repos/NixOS/nixpkgs/compare/$locked...$remote" 2>/dev/null | jq -r '.ahead_by // empty' 2>/dev/null)
if [ -n "${n:-}" ]; then text="󰚰 $n"; detail="$n new nixpkgs commits on $BRANCH"; else text="󰚰"; detail="nixpkgs $BRANCH has moved past your lock"; fi
emit "$text" "$detail\\nClick to see update commands" "has-updates"
