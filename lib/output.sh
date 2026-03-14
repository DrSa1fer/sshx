#!/usr/bin/env bash
# lib/output.sh — Color, icons, and output helpers

# Detect color support
_COLOR_ENABLED=false
if [[ -t 1 ]]; then
  _COLOR_ENABLED=true
fi

color() {
  if ! "$_COLOR_ENABLED"; then return; fi
  case "$1" in
    reset)  printf '\033[0m' ;;
    bold)   printf '\033[1m' ;;
    red)    printf '\033[31m' ;;
    green)  printf '\033[32m' ;;
    yellow) printf '\033[33m' ;;
    blue)   printf '\033[34m' ;;
    cyan)   printf '\033[36m' ;;
    gray)   printf '\033[90m' ;;
  esac
}

die() {
  printf '%s✗ %s%s\n' "$(color red)" "$*" "$(color reset)" >&2
  exit 1
}

info() {
  printf '%s %s%s\n' "$(color cyan)" "$*" "$(color reset)"
}

ok() {
  printf '%s✓ %s%s\n' "$(color green)" "$*" "$(color reset)"
}

warn() {
  printf '%s⚠ %s%s\n' "$(color yellow)" "$*" "$(color reset)" >&2
}

# Print a table from stdin: "COL1\tCOL2\t..." lines
# Usage: printf "..." | print_table [--no-header]
print_table() {
  local no_header=false
  [[ "${1:-}" == "--no-header" ]] && no_header=true

  if command -v column &>/dev/null; then
    if "$no_header"; then
      column -t -s $'\t'
    else
      # Bold first line
      local first=true
      while IFS= read -r line; do
        if "$first"; then
          first=false
          if "$_COLOR_ENABLED"; then
            printf '\033[1m%s\033[0m\n' "$line"
          else
            printf '%s\n' "$line"
          fi
        else
          printf '%s\n' "$line"
        fi
      done | column -t -s $'\t'
    fi
  else
    cat
  fi
}

# Confirm prompt; returns 0 if yes
confirm() {
  local prompt="${1:-Are you sure?}"
  local reply
  printf '%s%s [y/N] %s' "$(color yellow)" "$prompt" "$(color reset)" >&2
  read -r reply </dev/tty
  [[ "$reply" =~ ^[Yy]$ ]]
}

# Apply --color / --json global flags (called early in commands)
apply_output_flags() {
  local color_setting
  color_setting="$(cfg_get color 2>/dev/null || echo auto)"
  case "$color_setting" in
    always) _COLOR_ENABLED=true ;;
    never)  _COLOR_ENABLED=false ;;
    auto)   ;; # already set by TTY check
  esac
}
