#!/usr/bin/env bash
# lib/completion.sh — generate shell completion scripts

cmd_completion() {
  local shell="${1:-}"
  case "$shell" in
    bash) _completion_bash ;;
    zsh)  _completion_zsh ;;
    fish) _completion_fish ;;
    --help|-h) echo "Usage: sshx completion bash|zsh|fish" ;;
    *) die "Unknown shell: '$shell'. Supported: bash, zsh, fish" ;;
  esac
}

_list_connections() {
  shopt -s nullglob
  for f in "${SSHX_HOME:-$HOME/.sshx}/config.d"/*.conf; do
    basename "$f" .conf
  done
  shopt -u nullglob
}

_completion_bash() {
  cat <<'BASH'
# sshx bash completion
# Add to ~/.bashrc: eval "$(sshx completion bash)"

_sshx_connections() {
  local sshx_home="${SSHX_HOME:-$HOME/.sshx}"
  for f in "$sshx_home/config.d"/*.conf 2>/dev/null; do
    [[ -f "$f" ]] && basename "$f" .conf
  done
}

_sshx_complete() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  local prev="${COMP_WORDS[COMP_CWORD-1]}"
  local cmd="${COMP_WORDS[1]}"
  local sub="${COMP_WORDS[2]:-}"

  local top_cmds="connect list search connection tag export import init config completion version help"
  local conn_subs="add edit set remove show rename copy check effective"
  local tag_subs="add remove list rename"
  local config_subs="set get"
  local conn_names; conn_names="$(_sshx_connections)"
  local shells="bash zsh fish"

  case "$cmd" in
    connect|ssh|c)
      COMPREPLY=($(compgen -W "$conn_names" -- "$cur"))
      ;;
    connection|conn)
      if [[ "$COMP_CWORD" -eq 2 ]]; then
        COMPREPLY=($(compgen -W "$conn_subs" -- "$cur"))
      elif [[ "$COMP_CWORD" -ge 3 ]]; then
        case "$sub" in
          remove|rm|delete|del|show|info|edit|check|validate|ping|effective|config|rename|mv|copy|cp|clone|set|update)
            COMPREPLY=($(compgen -W "$conn_names" -- "$cur"))
            ;;
        esac
      fi
      ;;
    tag)
      if [[ "$COMP_CWORD" -eq 2 ]]; then
        COMPREPLY=($(compgen -W "$tag_subs" -- "$cur"))
      elif [[ "$COMP_CWORD" -eq 3 && "$sub" != "list" ]]; then
        COMPREPLY=($(compgen -W "$conn_names" -- "$cur"))
      fi
      ;;
    export)
      if [[ "$COMP_CWORD" -eq 2 ]]; then
        COMPREPLY=($(compgen -W "--all $conn_names" -- "$cur"))
      fi
      ;;
    import)
      COMPREPLY=($(compgen -f -- "$cur"))
      ;;
    config)
      if [[ "$COMP_CWORD" -eq 2 ]]; then
        COMPREPLY=($(compgen -W "$config_subs" -- "$cur"))
      fi
      ;;
    completion)
      COMPREPLY=($(compgen -W "$shells" -- "$cur"))
      ;;
    *)
      if [[ "$COMP_CWORD" -eq 1 ]]; then
        COMPREPLY=($(compgen -W "$top_cmds" -- "$cur"))
      fi
      ;;
  esac
}

complete -F _sshx_complete sshx
BASH
}

_completion_zsh() {
  cat <<'ZSH'
# sshx zsh completion
# Add to ~/.zshrc: eval "$(sshx completion zsh)"
# Or: sshx completion zsh >> ~/.zshrc

_sshx() {
  local sshx_home="${SSHX_HOME:-$HOME/.sshx}"
  local -a conn_names
  for f in "$sshx_home/config.d"/*.conf(N); do
    conn_names+=("${f:t:r}")
  done

  local state

  _arguments -C \
    '1: :->cmd' \
    '*: :->args'

  case $state in
    cmd)
      _values 'command' \
        'connect[Connect to a saved host]' \
        'list[List all connections]' \
        'search[Search connections]' \
        'connection[Manage connections]' \
        'tag[Manage tags]' \
        'export[Export connections]' \
        'import[Import connections]' \
        'init[Initialize sshx]' \
        'config[sshx settings]' \
        'completion[Shell completion]' \
        'version[Show version]' \
        'help[Show help]'
      ;;
    args)
      case ${words[2]} in
        connect|ssh|c)
          _values 'connection' "${conn_names[@]}"
          ;;
        connection|conn)
          if [[ ${#words[@]} -eq 3 ]]; then
            _values 'subcommand' add edit set remove show rename copy check effective
          elif [[ ${#words[@]} -ge 4 ]]; then
            _values 'connection' "${conn_names[@]}"
          fi
          ;;
        tag)
          if [[ ${#words[@]} -eq 3 ]]; then
            _values 'subcommand' add remove list rename
          elif [[ ${#words[@]} -ge 4 && ${words[3]} != "list" ]]; then
            _values 'connection' "${conn_names[@]}"
          fi
          ;;
        export)
          _values 'name' --all "${conn_names[@]}"
          ;;
        import)
          _files
          ;;
        completion)
          _values 'shell' bash zsh fish
          ;;
        config)
          _values 'subcommand' set get
          ;;
      esac
      ;;
  esac
}

compdef _sshx sshx
ZSH
}

_completion_fish() {
  cat <<'FISH'
# sshx fish completion
# Usage: sshx completion fish > ~/.config/fish/completions/sshx.fish

function __sshx_connections
  set sshx_home (set -q SSHX_HOME; and echo $SSHX_HOME; or echo $HOME/.sshx)
  for f in $sshx_home/config.d/*.conf
    if test -f $f
      basename $f .conf
    end
  end
end

function __sshx_subcommand
  set -l cmd (commandline -poc)
  test (count $cmd) -ge 2; and echo $cmd[2]
end

# Top-level commands
complete -c sshx -f -n '__fish_use_subcommand' -a 'connect'    -d 'Connect to saved host'
complete -c sshx -f -n '__fish_use_subcommand' -a 'list'       -d 'List connections'
complete -c sshx -f -n '__fish_use_subcommand' -a 'search'     -d 'Search connections'
complete -c sshx -f -n '__fish_use_subcommand' -a 'connection' -d 'Manage connections'
complete -c sshx -f -n '__fish_use_subcommand' -a 'tag'        -d 'Manage tags'
complete -c sshx -f -n '__fish_use_subcommand' -a 'export'     -d 'Export connections'
complete -c sshx -f -n '__fish_use_subcommand' -a 'import'     -d 'Import connections'
complete -c sshx -f -n '__fish_use_subcommand' -a 'init'       -d 'Initialize sshx'
complete -c sshx -f -n '__fish_use_subcommand' -a 'config'     -d 'sshx settings'
complete -c sshx -f -n '__fish_use_subcommand' -a 'completion' -d 'Shell completions'
complete -c sshx -f -n '__fish_use_subcommand' -a 'version'    -d 'Show version'
complete -c sshx -f -n '__fish_use_subcommand' -a 'help'       -d 'Show help'

# connect — complete connection names
complete -c sshx -f -n '__fish_seen_subcommand_from connect ssh c' -a '(__sshx_connections)'

# connection subcommands
complete -c sshx -f -n '__fish_seen_subcommand_from connection' -a 'add edit set remove show rename copy check effective'

# connection sub + names
for subcmd in edit set remove show rename copy check effective
  complete -c sshx -f -n "__fish_seen_subcommand_from connection; and __fish_seen_subcommand_from $subcmd" \
    -a '(__sshx_connections)'
end

# tag subcommands
complete -c sshx -f -n '__fish_seen_subcommand_from tag' -a 'add remove list rename'

# completion shells
complete -c sshx -f -n '__fish_seen_subcommand_from completion' -a 'bash zsh fish'
FISH
}
