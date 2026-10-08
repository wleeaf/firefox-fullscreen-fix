#!/usr/bin/env bash
#
# Stops Firefox from revealing its toolbar and tabs when the mouse touches the
# top edge in F11 fullscreen mode, and keeps them hidden until F11 is pressed.
#
# Works on Fedora, Debian, Ubuntu and their derivatives. Only bash, awk and
# coreutils are used.
#
# Usage:
#   ./fix-firefox-fullscreen.sh              apply the fix to every Firefox profile
#   ./fix-firefox-fullscreen.sh --uninstall  remove the fix
#
# Restart Firefox after running the script.

set -euo pipefail

# Markers wrap the lines this script adds to user.js, so they can be found and removed later.
# user.js uses JavaScript-style comments, so the markers use "//".
MARK_BEGIN="// >>> firefox-fullscreen-fix >>>"
MARK_END="// <<< firefox-fullscreen-fix <<<"

CSS_CONTENT='@namespace url("http://www.mozilla.org/keymaster/gatekeeper/there.is.only.xul");
@namespace html url("http://www.w3.org/1999/xhtml");

/* Hide the invisible mouseover trigger that reveals the toolbar in fullscreen. */
*|div#fullscr-toggler {
  display: none !important;
}
'

usage() {
  sed -n '3,14p' "$0" | sed 's/^# \{0,1\}//'
}

die() {
  echo "error: $*" >&2
  exit 1
}

# Print each Firefox profile root directory that may exist on this machine.
# FF_ROOTS can override the list, separated by colons (used for testing).
find_roots() {
  if [[ -n "${FF_ROOTS:-}" ]]; then
    tr ':' '\n' <<<"$FF_ROOTS"
    return
  fi
  printf '%s\n' \
    "$HOME/.config/mozilla/firefox" \
    "$HOME/.mozilla/firefox" \
    "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox"
}

# Print "<IsRelative> <Path>" for each profile listed in profiles.ini.
list_profiles() {
  local ini="$1/profiles.ini"
  [[ -f "$ini" ]] || return 0
  awk '
    /^\[/        { if (path != "") print rel, path; path = ""; rel = 1; next }
    /^IsRelative=/ { rel = substr($0, 12) }
    /^Path=/     { path = substr($0, 6) }
    END          { if (path != "") print rel, path }
  ' "$ini"
}

# Remove our block from a user.js file, keeping everything else.
strip_block() {
  awk -v b="$MARK_BEGIN" -v e="$MARK_END" '
    index($0, b) == 1 { skip = 1; next }
    index($0, e) == 1 { skip = 0; next }
    !skip
  ' "$1"
}

install_profile() {
  local dir="$1" css="$1/chrome/userChrome.css" userjs="$1/user.js"

  mkdir -p "$dir/chrome"

  # Back up an existing userChrome.css that we did not write.
  if [[ -f "$css" ]] && ! cmp -s <(printf '%s' "$CSS_CONTENT") "$css"; then
    cp "$css" "$css.bak.$(date +%Y%m%d%H%M%S)"
    echo "    backed up existing userChrome.css"
  fi
  printf '%s' "$CSS_CONTENT" > "$css"

  local tmp="$userjs.tmp"
  if [[ -f "$userjs" ]]; then
    strip_block "$userjs" > "$tmp"
  else
    : > "$tmp"
  fi
  {
    echo "$MARK_BEGIN"
    echo 'user_pref("browser.fullscreen.autohide", true);'
    echo 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);'
    echo "$MARK_END"
  } >> "$tmp"
  mv "$tmp" "$userjs"
}

uninstall_profile() {
  local dir="$1" css="$1/chrome/userChrome.css" userjs="$1/user.js"

  if [[ -f "$css" ]] && cmp -s <(printf '%s' "$CSS_CONTENT") "$css"; then
    rm -f "$css"
    echo "    removed userChrome.css"
  fi
  if [[ -f "$userjs" ]] && grep -qF "$MARK_BEGIN" "$userjs"; then
    local tmp="$userjs.tmp"
    strip_block "$userjs" > "$tmp"
    if [[ -s "$tmp" ]]; then
      mv "$tmp" "$userjs"
    else
      rm -f "$tmp" "$userjs"
    fi
    echo "    removed fix from user.js"
  fi
}

main() {
  local action=install arg
  for arg in "$@"; do
    case "$arg" in
      --uninstall) action=uninstall ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown option: $arg (see --help)" ;;
    esac
  done

  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    echo "Detected: ${PRETTY_NAME:-unknown}"
  fi

  local found=0 root rel path dir
  while IFS= read -r root; do
    [[ -d "$root" ]] || continue
    while read -r rel path; do
      [[ -n "$path" ]] || continue
      if [[ "$rel" == 1 ]]; then
        dir="$root/$path"
      else
        dir="$path"
      fi
      [[ -d "$dir" ]] || continue
      found=$((found + 1))
      echo "Profile: $dir"
      if [[ "$action" == install ]]; then
        install_profile "$dir"
      else
        uninstall_profile "$dir"
      fi
    done < <(list_profiles "$root")
  done < <(find_roots)

  if (( found == 0 )); then
    die "no Firefox profiles found (checked ~/.config/mozilla/firefox, ~/.mozilla/firefox and the Flatpak location)"
  fi

  echo
  if [[ "$action" == install ]]; then
    echo "Done. Fixed $found profile(s). Restart Firefox, then press F11."
  else
    echo "Done. Removed the fix from $found profile(s). Restart Firefox."
  fi

  if pgrep -x firefox >/dev/null 2>&1 || pgrep -x firefox-esr >/dev/null 2>&1; then
    echo "Note: Firefox is running. Close and reopen it for the change to apply."
  fi
}

main "$@"
