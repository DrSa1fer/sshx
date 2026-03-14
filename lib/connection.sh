#!/usr/bin/env bash
# lib/connection.sh — connection CRUD and connect/list/search commands

# ─── SSH parameter flags ─────────────────────────────────────────────────────
# Maps sshx CLI flag name → SSH config directive
declare -A SSH_FLAG_MAP=(
  [host]=HostName
  [user]=User
  [port]=Port
  [address-family]=AddressFamily
  [bind-address]=BindAddress
  [connect-timeout]=ConnectTimeout
  [identity]=IdentityFile
  [identity-agent]=IdentityAgent
  [pubkey-auth]=PubkeyAuthentication
  [password-auth]=PasswordAuthentication
  [kbd-interactive]=KbdInteractiveAuthentication
  [gssapi-auth]=GSSAPIAuthentication
  [gssapi-delegate]=GSSAPIDelegateCredentials
  [preferred-auth]=PreferredAuthentications
  [host-based-auth]=HostbasedAuthentication
  [number-of-password-prompts]=NumberOfPasswordPrompts
  [strict-host-key-checking]=StrictHostKeyChecking
  [known-hosts]=UserKnownHostsFile
  [global-known-hosts]=GlobalKnownHostsFile
  [host-key-algorithms]=HostKeyAlgorithms
  [check-host-ip]=CheckHostIP
  [verify-host-key-dns]=VerifyHostKeyDNS
  [revoked-host-keys]=RevokedHostKeys
  [ciphers]=Ciphers
  [macs]=MACs
  [kex-algorithms]=KexAlgorithms
  [pubkey-accepted-algorithms]=PubkeyAcceptedAlgorithms
  [ca-signature-algorithms]=CASignatureAlgorithms
  [required-rsa-size]=RequiredRSASize
  [jump]=ProxyJump
  [proxy-command]=ProxyCommand
  [local-forward]=LocalForward
  [remote-forward]=RemoteForward
  [dynamic-forward]=DynamicForward
  [exit-on-forward-failure]=ExitOnForwardFailure
  [clear-all-forwardings]=ClearAllForwardings
  [control-master]=ControlMaster
  [control-path]=ControlPath
  [control-persist]=ControlPersist
  [server-alive-interval]=ServerAliveInterval
  [server-alive-count-max]=ServerAliveCountMax
  [tcp-keepalive]=TCPKeepAlive
  [forward-agent]=ForwardAgent
  [forward-x11]=ForwardX11
  [forward-x11-trusted]=ForwardX11Trusted
  [forward-x11-timeout]=ForwardX11Timeout
  [x-auth-location]=XAuthLocation
  [request-tty]=RequestTTY
  [send-env]=SendEnv
  [set-env]=SetEnv
  [accept-env]=AcceptEnv
  [remote-command]=RemoteCommand
  [permit-local-command]=PermitLocalCommand
  [local-command]=LocalCommand
  [compression]=Compression
  [compression-level]=CompressionLevel
  [log-level]=LogLevel
  [log-verbose]=LogVerbose
  [escape-char]=EscapeChar
  [banner]=VisualHostKey
  [hash-known-hosts]=HashKnownHosts
  [add-keys-to-agent]=AddKeysToAgent
  [rekey-limit]=RekeyLimit
  [session-type]=SessionType
  [stdin-null]=StdinNull
  [fork-after-authentication]=ForkAfterAuthentication
  [tunnel]=Tunnel
  [tunnel-device]=TunnelDevice
  [permit-remote-open]=PermitRemoteOpen
  [security-key-provider]=SecurityKeyProvider
  [pkcs11-provider]=PKCS11Provider
  [ignored-unknown]=IgnoredUnknownOption
)

# ─── connect ────────────────────────────────────────────────────────────────

cmd_connect() {
  local dry_run=false
  local name=""
  local extra_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) dry_run=true; shift ;;
      --help|-h) cat <<'EOF'
Usage: sshx connect [NAME] [SSH_ARGS...]

Connect to a saved SSH host. If NAME is omitted and fzf is available,
opens interactive fuzzy finder.

Options:
  --dry-run    Print the ssh command without executing it

Examples:
  sshx connect prod-web
  sshx connect prod-web -t 'tmux attach'
  sshx connect        # interactive fzf selection
EOF
        return ;;
      -*) extra_args+=("$1"); shift ;;
      *)
        if [[ -z "$name" ]]; then
          name="$1"
        else
          extra_args+=("$1")
        fi
        shift ;;
    esac
  done

  # fzf interactive selection
  if [[ -z "$name" ]]; then
    if command -v fzf &>/dev/null; then
      local preview_enabled; preview_enabled=$(cfg_get fzf_preview)
      local fzf_opts=()
      if [[ "$preview_enabled" == "true" ]]; then
        fzf_opts+=(--preview "grep -A20 '^Host ' \"\$SSHX_HOME/config.d/{}.conf\" 2>/dev/null || echo 'No preview'")
      fi
      name=$(conn_files | xargs -I{} basename {} .conf | \
             fzf --height=40% --reverse "${fzf_opts[@]}" 2>/dev/null) || die "No connection selected."
    else
      die "NAME required. Install fzf for interactive selection."
    fi
  fi

  conn_must_exist "$name"

  local ssh_cmd=("ssh" "$name" "${extra_args[@]}")

  if "$dry_run"; then
    info "Would run: ${ssh_cmd[*]}"
    return
  fi

  exec "${ssh_cmd[@]}"
}

# ─── list ───────────────────────────────────────────────────────────────────

cmd_list() {
  local tag_filter=() format="table" sort_field="name" reverse=false no_header=false json=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tag) tag_filter+=("$2"); shift 2 ;;
      --format) format="$2"; shift 2 ;;
      --sort) sort_field="$2"; shift 2 ;;
      --reverse|-r) reverse=true; shift ;;
      --no-header) no_header=true; shift ;;
      --json) json=true; format="json"; shift ;;
      --help|-h) cat <<'EOF'
Usage: sshx list [options]

Options:
  --tag TAG              Filter by tag (repeatable, AND logic)
  --format table|wide|json|ssh  Output format
  --sort name|host|port|created|updated
  --reverse, -r          Reverse sort order
  --no-header            Omit table header
  --json                 JSON output (alias for --format json)
EOF
        return ;;
      *) die "Unknown flag: $1" ;;
    esac
  done

  local files=()
  while IFS= read -r f; do
    [[ -n "$f" ]] && files+=("$f")
  done < <(conn_files)

  [[ ${#files[@]} -gt 0 ]] || { info "No connections found. Run 'sshx connection add' to create one."; return; }

  # Build data rows: name|host|port|user|description|tags|created|updated
  local -a rows=()
  for f in "${files[@]}"; do
    local name host port user desc tags created updated
    name=$(conn_meta "$f" name)
    host=$(conn_ssh "$f" HostName)
    port=$(conn_ssh "$f" Port); [[ -n "$port" ]] || port="22"
    user=$(conn_ssh "$f" User); [[ -n "$user" ]] || user="-"
    desc=$(conn_meta "$f" description); [[ -n "$desc" ]] || desc="-"
    tags=$(conn_meta "$f" tags); [[ -n "$tags" ]] || tags="-"
    created=$(conn_meta "$f" created_at); [[ -n "$created" ]] || created="-"
    updated=$(conn_meta "$f" updated_at); [[ -n "$updated" ]] || updated="-"

    # Tag filter (AND)
    if [[ ${#tag_filter[@]} -gt 0 ]]; then
      local match=true
      for tf in "${tag_filter[@]}"; do
        if [[ "$tags" != *"$tf"* ]]; then match=false; break; fi
      done
      "$match" || continue
    fi

    rows+=("${name}|${host}|${port}|${user}|${desc}|${tags}|${created}|${updated}")
  done

  [[ ${#rows[@]} -gt 0 ]] || { info "No connections match the filter."; return; }

  # Sort
  local sort_col=0
  case "$sort_field" in
    name)    sort_col=0 ;;
    host)    sort_col=1 ;;
    port)    sort_col=2 ;;
    created) sort_col=6 ;;
    updated) sort_col=7 ;;
  esac

  local sort_flags=("-t|" "-k$((sort_col+1))")
  "$reverse" && sort_flags+=("-r")
  IFS=$'\n' rows=($(printf '%s\n' "${rows[@]}" | sort "${sort_flags[@]}"))

  # Output
  case "$format" in
    json)
      printf '[\n'
      local first=true
      for row in "${rows[@]}"; do
        IFS='|' read -r n h po u d tg cr up <<< "$row"
        "$first" || printf ',\n'
        first=false
        printf '  {"name":"%s","host":"%s","port":"%s","user":"%s","description":"%s","tags":"%s","created_at":"%s","updated_at":"%s"}' \
          "$n" "$h" "$po" "$u" "$d" "$tg" "$cr" "$up"
      done
      printf '\n]\n'
      ;;
    ssh)
      for row in "${rows[@]}"; do
        IFS='|' read -r n h po u _ _ _ _ <<< "$row"
        printf 'Host %s\n    HostName %s\n    Port %s\n' "$n" "$h" "$po"
        [[ "$u" != "-" ]] && printf '    User %s\n' "$u"
        printf '\n'
      done
      ;;
    wide)
      {
        "$no_header" || printf 'NAME\tHOST\tPORT\tUSER\tDESCRIPTION\tTAGS\tUPDATED\n'
        for row in "${rows[@]}"; do
          IFS='|' read -r n h po u d tg _ up <<< "$row"
          printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$n" "$h" "$po" "$u" "$d" "$tg" "$up"
        done
      } | print_table $("$no_header" && echo "--no-header" || true)
      ;;
    *)  # table
      {
        "$no_header" || printf 'NAME\tHOST\tPORT\tDESCRIPTION\tTAGS\n'
        for row in "${rows[@]}"; do
          IFS='|' read -r n h po u d tg _ _ <<< "$row"
          printf '%s\t%s\t%s\t%s\t%s\n' "$n" "$h" "$po" "$d" "$tg"
        done
      } | print_table $("$no_header" && echo "--no-header" || true)
      ;;
  esac
}

# ─── search ─────────────────────────────────────────────────────────────────

cmd_search() {
  local term="" field="any" regex=false format="table"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --field) field="$2"; shift 2 ;;
      --regex) regex=true; shift ;;
      --format) format="$2"; shift 2 ;;
      --json) format="json"; shift ;;
      --help|-h) cat <<'EOF'
Usage: sshx search TERM [options]

Search connections by name, host, user, description, or tags.

Options:
  --field name|host|user|desc|tag|any   Restrict to specific field
  --regex                               Interpret TERM as regex
  --format table|json                   Output format
EOF
        return ;;
      -*) die "Unknown flag: $1" ;;
      *) term="$1"; shift ;;
    esac
  done

  [[ -n "$term" ]] || die "TERM required. Usage: sshx search TERM"

  local -a results=()
  for f in $(conn_files); do
    local name host user desc tags
    name=$(conn_meta "$f" name)
    host=$(conn_ssh "$f" HostName)
    user=$(conn_ssh "$f" User)
    desc=$(conn_meta "$f" description)
    tags=$(conn_meta "$f" tags)

    local haystack=""
    case "$field" in
      name) haystack="$name" ;;
      host) haystack="$host" ;;
      user) haystack="$user" ;;
      desc) haystack="$desc" ;;
      tag)  haystack="$tags" ;;
      *)    haystack="${name} ${host} ${user} ${desc} ${tags}" ;;
    esac

    local matched=false
    if "$regex"; then
      [[ "$haystack" =~ $term ]] && matched=true
    else
      [[ "$haystack" == *"$term"* ]] && matched=true
    fi

    "$matched" && results+=("${name}|${host}|${desc}|${tags}")
  done

  [[ ${#results[@]} -gt 0 ]] || { info "No connections match '$term'."; return; }

  if [[ "$format" == "json" ]]; then
    printf '[\n'
    local first=true
    for r in "${results[@]}"; do
      IFS='|' read -r n h d tg <<< "$r"
      "$first" || printf ',\n'
      first=false
      printf '  {"name":"%s","host":"%s","description":"%s","tags":"%s"}' "$n" "$h" "$d" "$tg"
    done
    printf '\n]\n'
  else
    {
      printf 'NAME\tHOST\tDESCRIPTION\tTAGS\n'
      for r in "${results[@]}"; do
        IFS='|' read -r n h d tg <<< "$r"
        printf '%s\t%s\t%s\t%s\n' "$n" "$h" "$d" "$tg"
      done
    } | print_table
  fi
}

# ─── connection add ──────────────────────────────────────────────────────────

cmd_connection_add() {
  local name="" conn_str="" description="" tags="" force=false
  local -a ssh_extras=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --description|-d) description="$2"; shift 2 ;;
      --tags) tags="$2"; shift 2 ;;
      --force) force=true; shift ;;
      --help|-h) cat <<'EOF'
Usage: sshx connection add [NAME] USER@HOST[:PORT] [options]

Create a new SSH connection.

Options:
  --description TEXT, -d TEXT   Human-readable description
  --tags TAG1,TAG2              Comma-separated tags
  --force                       Overwrite existing connection
  [SSH options from section 5]  Any supported SSH parameter

Example:
  sshx connection add prod deploy@10.0.1.5:2222 --description 'Production' --tags prod,web
EOF
        return ;;
      --*=*)
        local flag="${1%%=*}"; flag="${flag#--}"
        local val="${1#*=}"
        ssh_extras+=("$flag" "$val"); shift ;;
      --*)
        local flag="${1#--}"
        ssh_extras+=("$flag" "$2"); shift 2 ;;
      *)
        if [[ -z "$conn_str" && ("$1" == *"@"* || "$1" =~ ^[0-9a-zA-Z._-]+$ ) ]]; then
          # Could be conn_str or name
          if [[ -z "$name" && "$1" != *"@"* && "$1" != *"."* ]]; then
            name="$1"
          else
            conn_str="$1"
          fi
        fi
        shift ;;
    esac
  done

  [[ -n "$conn_str" ]] || die "USER@HOST[:PORT] required."

  # Auto-generate name from hostname
  if [[ -z "$name" ]]; then
    local _u _h _p
    parse_conn_string "$conn_str" _u _h _p
    name="${_h%%.*}"
    name="${name//[^a-zA-Z0-9_-]/-}"
  fi

  conn_validate_name "$name"

  local file; file=$(conn_file "$name")

  if [[ -f "$file" ]] && ! "$force"; then
    die "Connection '$name' already exists. Use --force to overwrite."
  fi

  backup_conn "$file"
  write_conn_file "$file" "$name" "$conn_str" "$description" "$tags"

  # Apply additional SSH flags
  local i=0
  while [[ $i -lt ${#ssh_extras[@]} ]]; do
    local flag="${ssh_extras[$i]}" val="${ssh_extras[$((i+1))]}"
    if [[ -n "${SSH_FLAG_MAP[$flag]:-}" ]]; then
      update_ssh_directive "$file" "${SSH_FLAG_MAP[$flag]}" "$val"
    fi
    i=$((i+2))
  done

  # Update tag symlinks
  _tags_sync "$name" "$tags"

  ok "Created connection '$name' → ${conn_str}"
  backups_prune
}

# ─── connection set ──────────────────────────────────────────────────────────

cmd_connection_set() {
  [[ $# -ge 1 ]] || die "Usage: sshx connection set NAME [options]"
  local name="$1"; shift
  conn_must_exist "$name"

  local file; file=$(conn_file "$name")
  backup_conn "$file"

  local description="" tags="" to_remove=() to_add=()
  local -a ssh_flags=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --description|-d) description="$2"; shift 2 ;;
      --tags) tags="$2"; shift 2 ;;
      --remove) to_remove+=("$2"); shift 2 ;;
      --add) to_add+=("$2" "$3"); shift 3 ;;
      --help|-h) cat <<'EOF'
Usage: sshx connection set NAME [options]

Modify parameters of an existing connection.

Options:
  --description TEXT, -d    Update description
  --tags TAG1,TAG2          Replace tags
  --remove PARAM            Remove SSH parameter (repeatable)
  --add PARAM VALUE         Add SSH parameter without replacing
  [SSH options]             Update SSH parameter
EOF
        return ;;
      --*=*)
        local flag="${1%%=*}"; flag="${flag#--}"
        local val="${1#*=}"
        ssh_flags+=("$flag" "$val"); shift ;;
      --*)
        local flag="${1#--}"
        ssh_flags+=("$flag" "$2"); shift 2 ;;
      *) die "Unknown argument: $1" ;;
    esac
  done

  [[ -n "$description" ]] && update_meta "$file" "description" "$description"
  if [[ -n "$tags" ]]; then
    update_meta "$file" "tags" "$tags"
    _tags_sync "$name" "$tags"
  fi

  for param in "${to_remove[@]}"; do
    remove_ssh_directive "$file" "$param"
  done

  local i=0
  while [[ $i -lt ${#to_add[@]} ]]; do
    local k="${to_add[$i]}" v="${to_add[$((i+1))]}"
    # Append without replacing (for MultiValue params)
    printf '    %s %s\n' "$k" "$v" >> "$file"
    i=$((i+2))
  done

  local i=0
  while [[ $i -lt ${#ssh_flags[@]} ]]; do
    local flag="${ssh_flags[$i]}" val="${ssh_flags[$((i+1))]}"
    if [[ -n "${SSH_FLAG_MAP[$flag]:-}" ]]; then
      update_ssh_directive "$file" "${SSH_FLAG_MAP[$flag]}" "$val"
    fi
    i=$((i+2))
  done

  touch_updated "$file"
  ok "Updated connection '$name'"
}

# ─── connection show ─────────────────────────────────────────────────────────

cmd_connection_show() {
  [[ $# -ge 1 ]] || die "Usage: sshx connection show NAME"
  local name="$1" format="pretty"
  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --format) format="$2"; shift 2 ;;
      --help|-h) echo "Usage: sshx connection show NAME [--format pretty|raw|json]"; return ;;
      *) die "Unknown flag: $1" ;;
    esac
  done

  conn_must_exist "$name"
  local file; file=$(conn_file "$name")

  case "$format" in
    raw)  cat "$file" ;;
    json)
      local n h po u d tg cr up cs
      n=$(conn_meta "$file" name)
      h=$(conn_ssh "$file" HostName)
      po=$(conn_ssh "$file" Port); [[ -n "$po" ]] || po="22"
      u=$(conn_ssh "$file" User)
      d=$(conn_meta "$file" description)
      tg=$(conn_meta "$file" tags)
      cr=$(conn_meta "$file" created_at)
      up=$(conn_meta "$file" updated_at)
      cs=$(conn_meta "$file" connection_string)
      printf '{"name":"%s","host":"%s","port":"%s","user":"%s","description":"%s","tags":"%s","created_at":"%s","updated_at":"%s","connection_string":"%s"}\n' \
        "$n" "$h" "$po" "$u" "$d" "$tg" "$cr" "$up" "$cs"
      ;;
    *)
      local n h po u d tg cr up
      n=$(conn_meta "$file" name)
      h=$(conn_ssh "$file" HostName)
      po=$(conn_ssh "$file" Port); [[ -n "$po" ]] || po="22"
      u=$(conn_ssh "$file" User)
      d=$(conn_meta "$file" description)
      tg=$(conn_meta "$file" tags)
      cr=$(conn_meta "$file" created_at)
      up=$(conn_meta "$file" updated_at)
      printf '%s%-18s%s %s\n' "$(color bold)" "Name:" "$(color reset)" "$n"
      printf '%-18s %s\n' "Host:" "$h"
      printf '%-18s %s\n' "Port:" "$po"
      [[ -n "$u" ]] && printf '%-18s %s\n' "User:" "$u"
      [[ -n "$d" ]] && printf '%-18s %s\n' "Description:" "$d"
      [[ -n "$tg" ]] && printf '%-18s %s\n' "Tags:" "$tg"
      [[ -n "$cr" ]] && printf '%-18s %s\n' "Created:" "$cr"
      [[ -n "$up" ]] && printf '%-18s %s\n' "Updated:" "$up"
      printf '\n%s--- SSH Config ---%s\n' "$(color gray)" "$(color reset)"
      grep -v '^# sshx:' "$file" | grep -v '^$'
      ;;
  esac
}

# ─── connection rename ───────────────────────────────────────────────────────

cmd_connection_rename() {
  [[ $# -ge 2 ]] || die "Usage: sshx connection rename OLD NEW"
  local old="$1" new="$2"
  conn_must_exist "$old"
  conn_validate_name "$new"
  [[ ! -f "$(conn_file "$new")" ]] || die "Connection '$new' already exists."

  local old_file; old_file=$(conn_file "$old")
  local new_file; new_file=$(conn_file "$new")

  backup_conn "$old_file"

  # Update metadata and Host directive
  local tmp; tmp=$(mktemp); chmod 600 "$tmp"
  sed -e "s|^# sshx:name=.*|# sshx:name=${new}|" \
      -e "s|^Host ${old}$|Host ${new}|" \
      "$old_file" > "$tmp"
  mv "$tmp" "$new_file"
  chmod 600 "$new_file"
  rm "$old_file"

  # Update tag symlinks
  local tags; tags=$(conn_meta "$new_file" tags)
  _tags_remove_all "$old"
  _tags_sync "$new" "$tags"

  touch_updated "$new_file"
  ok "Renamed '$old' → '$new'"
}

# ─── connection copy ─────────────────────────────────────────────────────────

cmd_connection_copy() {
  [[ $# -ge 2 ]] || die "Usage: sshx connection copy SOURCE NEW"
  local src="$1" new="$2"; shift 2
  conn_must_exist "$src"
  conn_validate_name "$new"
  [[ ! -f "$(conn_file "$new")" ]] || die "Connection '$new' already exists."

  local src_file; src_file=$(conn_file "$src")
  local new_file; new_file=$(conn_file "$new")

  local now; now=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)
  local tmp; tmp=$(mktemp); chmod 600 "$tmp"
  sed -e "s|^# sshx:name=.*|# sshx:name=${new}|" \
      -e "s|^# sshx:created_at=.*|# sshx:created_at=${now}|" \
      -e "s|^# sshx:updated_at=.*|# sshx:updated_at=${now}|" \
      -e "s|^Host ${src}$|Host ${new}|" \
      "$src_file" > "$tmp"
  mv "$tmp" "$new_file"
  chmod 600 "$new_file"

  # Apply overrides from extra flags
  cmd_connection_set "$new" "$@" 2>/dev/null || true

  local tags; tags=$(conn_meta "$new_file" tags)
  _tags_sync "$new" "$tags"
  ok "Copied '$src' → '$new'"
}

# ─── connection remove ───────────────────────────────────────────────────────

cmd_connection_remove() {
  [[ $# -ge 1 ]] || die "Usage: sshx connection remove NAME"
  local name="$1" force=false no_backup=false
  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force|-f) force=true; shift ;;
      --no-backup) no_backup=true; shift ;;
      --help|-h) echo "Usage: sshx connection remove NAME [--force] [--no-backup]"; return ;;
      *) die "Unknown flag: $1" ;;
    esac
  done

  conn_must_exist "$name"

  if ! "$force"; then
    confirm "Delete connection '$name'?" || { info "Aborted."; return; }
  fi

  local file; file=$(conn_file "$name")
  "$no_backup" || backup_conn "$file"
  rm "$file"
  _tags_remove_all "$name"
  ok "Removed connection '$name'"
}

# ─── connection check ────────────────────────────────────────────────────────

cmd_connection_check() {
  [[ $# -ge 1 ]] || die "Usage: sshx connection check NAME"
  local name="$1" config_only=false timeout=5
  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --config-only) config_only=true; shift ;;
      --timeout) timeout="$2"; shift 2 ;;
      --help|-h) echo "Usage: sshx connection check NAME [--config-only] [--timeout N]"; return ;;
      *) die "Unknown flag: $1" ;;
    esac
  done

  conn_must_exist "$name"

  # Phase 1: config validation
  if ssh -G "$name" &>/dev/null; then
    ok "Config valid (ssh -G passed)"
  else
    die "Config invalid — run 'ssh -G $name' to see errors."
  fi

  "$config_only" && return

  # Phase 2: real connectivity
  info "Testing connectivity (timeout ${timeout}s)…"
  if ssh -o BatchMode=yes -o ConnectTimeout="$timeout" -o StrictHostKeyChecking=no \
         "$name" exit 0 &>/dev/null; then
    ok "Connection successful"
  else
    warn "Could not connect (host may be unreachable or require interactive auth)"
  fi
}

# ─── connection effective ────────────────────────────────────────────────────

cmd_connection_effective() {
  [[ $# -ge 1 ]] || die "Usage: sshx connection effective NAME"
  local name="$1"
  conn_must_exist "$name"
  ssh -G "$name"
}

# ─── connection edit ─────────────────────────────────────────────────────────

cmd_connection_edit() {
  [[ $# -ge 1 ]] || die "Usage: sshx connection edit NAME"
  local name="$1"
  conn_must_exist "$name"

  local file; file=$(conn_file "$name")
  backup_conn "$file"

  local editor; editor=$(cfg_get editor)
  "$editor" "$file"

  touch_updated "$file"

  # Warn on syntax errors
  if ! ssh -G "$name" &>/dev/null; then
    warn "SSH config syntax error detected. Check with: ssh -G $name"
  else
    ok "Saved. Config valid."
  fi
}
