#!/usr/bin/env bash
# lib/config.sh — sshx settings and connection file I/O

# ─── sshx Settings ──────────────────────────────────────────────────────────

cfg_get() {
  local key="$1"
  local default="${2:-}"
  if [[ -f "$SSHX_CONFIG" ]]; then
    local val
    val=$(grep -m1 "^${key}=" "$SSHX_CONFIG" 2>/dev/null | cut -d= -f2- || true)
    if [[ -n "$val" ]]; then
      echo "$val"
      return
    fi
  fi
  # Built-in defaults
  case "$key" in
    editor)            echo "${EDITOR:-${VISUAL:-nano}}" ;;
    default_tags)      echo "" ;;
    backup_enabled)    echo "true" ;;
    backup_max_age_days) echo "30" ;;
    color)             echo "auto" ;;
    fzf_preview)       echo "true" ;;
    *)                 echo "$default" ;;
  esac
}

cfg_set() {
  local key="$1" value="$2"
  [[ -f "$SSHX_CONFIG" ]] || touch "$SSHX_CONFIG"
  if grep -q "^${key}=" "$SSHX_CONFIG" 2>/dev/null; then
    # Portable sed -i
    local tmp; tmp=$(mktemp)
    sed "s|^${key}=.*|${key}=${value}|" "$SSHX_CONFIG" > "$tmp"
    mv "$tmp" "$SSHX_CONFIG"
  else
    printf '%s=%s\n' "$key" "$value" >> "$SSHX_CONFIG"
  fi
}

cmd_config_set() {
  [[ $# -ge 2 ]] || die "Usage: sshx config set KEY VALUE"
  cfg_set "$1" "$2"
  ok "Set $1=$2"
}

cmd_config_get() {
  local key="${1:-}"
  if [[ -n "$key" ]]; then
    cfg_get "$key"
  else
    for k in editor default_tags backup_enabled backup_max_age_days color fzf_preview; do
      printf '%-24s %s\n' "$k" "$(cfg_get "$k")"
    done
  fi
}

# ─── Connection File Parsing ─────────────────────────────────────────────────

# Get a metadata field from a connection file
# conn_meta FILE FIELD
conn_meta() {
  local file="$1" field="$2"
  grep -m1 "^# sshx:${field}=" "$file" 2>/dev/null | cut -d= -f2- || true
}

# Get an SSH directive value from a connection file
# conn_ssh FILE DIRECTIVE
conn_ssh() {
  local file="$1" directive="$2"
  grep -im1 "^[[:space:]]*${directive}[[:space:]]" "$file" 2>/dev/null \
    | awk '{print $2}' || true
}

# List all connection files
conn_files() {
  shopt -s nullglob
  local f
  for f in "$SSHX_CONNECTIONS_DIR"/*.conf; do
    echo "$f"
  done
  shopt -u nullglob
}

# Resolve connection name to file path
conn_file() {
  local name="$1"
  echo "$SSHX_CONNECTIONS_DIR/${name}.conf"
}

# Validate connection name characters
conn_validate_name() {
  local name="$1"
  [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]] || die "Name '$name' contains invalid characters. Use [a-zA-Z0-9_-] only."
}

# Ensure connection exists
conn_must_exist() {
  local name="$1"
  [[ -f "$(conn_file "$name")" ]] || die "Connection '$name' not found."
}

# ─── Backup ──────────────────────────────────────────────────────────────────

backup_conn() {
  local file="$1"
  [[ "$(cfg_get backup_enabled)" == "true" ]] || return 0
  [[ -f "$file" ]] || return 0
  local ts; ts=$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null || date +%Y%m%dT%H%M%SZ)
  local name; name=$(basename "$file")
  mkdir -p "$SSHX_BACKUPS_DIR"
  cp "$file" "$SSHX_BACKUPS_DIR/${name}.${ts}"
}

# Prune old backups
backups_prune() {
  local max_age; max_age=$(cfg_get backup_max_age_days)
  [[ -d "$SSHX_BACKUPS_DIR" ]] || return 0
  find "$SSHX_BACKUPS_DIR" -maxdepth 1 -name "*.conf.*" -mtime "+${max_age}" -delete 2>/dev/null || true
}

# ─── Atomic Write ────────────────────────────────────────────────────────────

# Write content to a connection file atomically
# atomic_write DEST_FILE <<< content
atomic_write() {
  local dest="$1"
  local tmp; tmp=$(mktemp "${dest}.XXXXXX")
  chmod 600 "$tmp"
  cat > "$tmp"
  mv "$tmp" "$dest"
}

# ─── Connection File Writer ──────────────────────────────────────────────────

# Build and write a connection config file
# Args (associative array passed as nameref or individual vars)
write_conn_file() {
  local file="$1"
  local name="$2"
  local conn_string="$3"   # user@host[:port]
  local description="${4:-}"
  local tags="${5:-}"
  local created_at="${6:-}"
  local updated_at

  updated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)
  [[ -n "$created_at" ]] || created_at="$updated_at"

  # Parse connection string
  local user host port
  parse_conn_string "$conn_string" user host port

  # Append default_tags
  local def_tags; def_tags=$(cfg_get default_tags)
  if [[ -n "$def_tags" && -n "$tags" ]]; then
    tags="${tags},${def_tags}"
  elif [[ -n "$def_tags" ]]; then
    tags="$def_tags"
  fi

  # Generate content
  {
    printf '# sshx:name=%s\n' "$name"
    [[ -n "$description" ]] && printf '# sshx:description=%s\n' "$description"
    [[ -n "$tags" ]]        && printf '# sshx:tags=%s\n' "$tags"
    printf '# sshx:created_at=%s\n' "$created_at"
    printf '# sshx:updated_at=%s\n' "$updated_at"
    printf '# sshx:connection_string=%s\n' "$conn_string"
    printf '\n'
    printf 'Host %s\n' "$name"
    printf '    HostName %s\n' "$host"
    [[ -n "$user" ]] && printf '    User %s\n' "$user"
    [[ "$port" != "22" && -n "$port" ]] && printf '    Port %s\n' "$port"
  } | atomic_write "$file"
}

parse_conn_string() {
  local cs="$1"
  local -n _user="$2"
  local -n _host="$3"
  local -n _port="$4"

  _user="" _host="" _port="22"

  # user@host:port or user@host or host:port or host
  if [[ "$cs" == *"@"* ]]; then
    _user="${cs%%@*}"
    cs="${cs#*@}"
  fi

  # IPv6 [::1]:port
  if [[ "$cs" =~ ^\[([^\]]+)\]:([0-9]+)$ ]]; then
    _host="${BASH_REMATCH[1]}"
    _port="${BASH_REMATCH[2]}"
  elif [[ "$cs" =~ ^\[([^\]]+)\]$ ]]; then
    _host="${BASH_REMATCH[1]}"
  elif [[ "$cs" =~ ^([^:]+):([0-9]+)$ ]]; then
    _host="${BASH_REMATCH[1]}"
    _port="${BASH_REMATCH[2]}"
  else
    _host="$cs"
  fi
}

# Update a single metadata comment in place
update_meta() {
  local file="$1" field="$2" value="$3"
  local tmp; tmp=$(mktemp)
  chmod 600 "$tmp"
  if grep -q "^# sshx:${field}=" "$file"; then
    sed "s|^# sshx:${field}=.*|# sshx:${field}=${value}|" "$file" > "$tmp"
  else
    # Insert after first # sshx: line
    awk -v field="$field" -v val="$value" '
      /^# sshx:/ && !inserted { print; print "# sshx:" field "=" val; inserted=1; next }
      { print }
    ' "$file" > "$tmp"
  fi
  mv "$tmp" "$file"
  chmod 600 "$file"
}

# Update an SSH directive in place (or add it)
update_ssh_directive() {
  local file="$1" directive="$2" value="$3"
  local tmp; tmp=$(mktemp)
  chmod 600 "$tmp"
  if grep -qi "^[[:space:]]*${directive}[[:space:]]" "$file"; then
    sed -r "s|^([[:space:]]*)${directive}[[:space:]].*|\1${directive} ${value}|i" "$file" > "$tmp"
  else
    # Append inside Host block
    awk -v dir="$directive" -v val="$value" '
      /^Host / { host=1; print; next }
      host && /^[[:space:]]*$/ { print "    " dir " " val; host=0 }
      { print }
      END { if (host) print "    " dir " " val }
    ' "$file" > "$tmp"
  fi
  mv "$tmp" "$file"
  chmod 600 "$file"
}

# Remove an SSH directive from file
remove_ssh_directive() {
  local file="$1" directive="$2"
  local tmp; tmp=$(mktemp)
  chmod 600 "$tmp"
  grep -iv "^[[:space:]]*${directive}[[:space:]]" "$file" > "$tmp" || true
  mv "$tmp" "$file"
  chmod 600 "$file"
}

# Touch updated_at
touch_updated() {
  local file="$1"
  local now; now=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)
  update_meta "$file" "updated_at" "$now"
}

# ─── init ────────────────────────────────────────────────────────────────────

cmd_init() {
  local force=false dry_run=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force) force=true ;;
      --dry-run) dry_run=true ;;
      --help|-h) cat <<'EOF'
Usage: sshx init [--force] [--dry-run]

Initialize ~/.sshx directory and add Include to ~/.ssh/config.
Safe to run multiple times (idempotent).
EOF
        return ;;
      *) die "Unknown flag: $1" ;;
    esac
    shift
  done

  local include_line="Include ${SSHX_CONNECTIONS_DIR}/*.conf"

  if "$dry_run"; then
    info "Would create: $SSHX_CONNECTIONS_DIR/"
    info "Would create: $SSHX_TAGS_DIR/"
    info "Would create: $SSHX_BACKUPS_DIR/"
    info "Would add to $SSH_CONFIG: $include_line"
    return
  fi

  # Create dirs
  mkdir -p "$SSHX_CONNECTIONS_DIR" "$SSHX_TAGS_DIR" "$SSHX_BACKUPS_DIR"
  chmod 700 "$SSHX_HOME" "$SSHX_CONNECTIONS_DIR" "$SSHX_TAGS_DIR" "$SSHX_BACKUPS_DIR"

  ok "Created $SSHX_CONNECTIONS_DIR/"
  ok "Created $SSHX_TAGS_DIR/"
  ok "Created $SSHX_BACKUPS_DIR/"

  # Add Include to ~/.ssh/config
  mkdir -p "$SSH_HOME"
  chmod 700 "$SSH_HOME"
  touch "$SSH_CONFIG"
  chmod 600 "$SSH_CONFIG"

  if grep -qF "$include_line" "$SSH_CONFIG" 2>/dev/null && ! "$force"; then
    info "Include already present in $SSH_CONFIG"
  else
    if "$force" && grep -qF "Include.*sshx" "$SSH_CONFIG" 2>/dev/null; then
      local tmp; tmp=$(mktemp)
      grep -v "Include.*sshx" "$SSH_CONFIG" > "$tmp"
      mv "$tmp" "$SSH_CONFIG"
      chmod 600 "$SSH_CONFIG"
    fi
    # Prepend include
    local tmp; tmp=$(mktemp)
    { printf '%s\n\n' "$include_line"; cat "$SSH_CONFIG"; } > "$tmp"
    mv "$tmp" "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"
    ok "Added Include to $SSH_CONFIG"
  fi
}
