#!/usr/bin/env bash
# Keybinding cheat-sheet for Hyprland.
# Reads the LIVE binds from `hyprctl binds` (so it never goes stale), tags each
# by category, and shows a searchable list in wofi. Type e.g. "move" or
# "workspace" to filter. Selecting a line just closes (it's a reference).
set -euo pipefail

# Decode Hyprland's modmask bitmask -> readable names.
modname() {
    local m=$1 out=""
    (( m & 64 )) && out+="SUPER+"
    (( m & 4 ))  && out+="CTRL+"
    (( m & 8 ))  && out+="ALT+"
    (( m & 1 ))  && out+="SHIFT+"
    printf '%s' "${out%+}"
}

# Bucket a dispatcher into a friendly category for grouping/searching.
category() {
    case "$1" in
        movefocus|movewindow|swapwindow|swapactiveworkspaces) echo "move  " ;;
        resizeactive|resizewindow)                            echo "resize" ;;
        workspace|movetoworkspace|movetoworkspacesilent)      echo "wkspc " ;;
        fullscreen|fullscreenstate|togglefloating|pseudo|killactive|layoutmsg) echo "window" ;;
        submap)                                               echo "mode  " ;;
        exec)                                                 echo "launch" ;;
        *)                                                    echo "misc  " ;;
    esac
}

# Map a raw keycode (used when a bind has no named key, e.g. media keys) to a
# friendly label. Falls back to code-N.
keyname() {
    case "$1" in
        121) echo "Mute" ;;      122) echo "VolDown" ;;   123) echo "VolUp" ;;
        232) echo "BrightDown";; 233) echo "BrightUp" ;;
        171) echo "Next" ;;      172) echo "Play/Pause";; 173) echo "Prev" ;;
        65)  echo "Space" ;;
        0)   echo "" ;;
        *)   echo "code-$1" ;;
    esac
}

build() {
    # Use 0x1F (unit separator) as delimiter — it's NOT IFS whitespace, so empty
    # fields (e.g. keycode-only binds) are preserved instead of collapsing.
    hyprctl binds -j | jq -r '.[] | [(.modmask|tostring), .key, (.keycode|tostring), .dispatcher, .arg] | join("")' |
    while IFS=$'\x1f' read -r mask key keycode disp arg; do
        [ -z "$key" ] && key=$(keyname "$keycode")
        [ -z "$key" ] && continue
        mods=$(modname "$mask")
        combo="${mods:+$mods+}$key"
        cat=$(category "$disp")
        case "$disp" in
            exec) action="$arg" ;;
            *)    action="$disp${arg:+ $arg}" ;;
        esac
        # strip pango-confusing chars so wofi doesn't choke
        action=${action//&/and}
        printf '%s   %-26s   %s\n' "$cat" "$combo" "$action"
    done
}

# --dry-run: just print (used for testing without a GUI)
if [ "${1:-}" = "--dry-run" ]; then
    build | sort
    exit 0
fi

build | sort | wofi --dmenu --insensitive --prompt "Keybindings" --lines 25 --width 1000 >/dev/null || true
