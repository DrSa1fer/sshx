#!/usr/bin/env bash
# lib/importexport.sh — import and export connections

cmd_export() {
  local all=false format="sshx" file=""
  local name=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --all) all=true; shift ;;
      --format) format="$2"; shift 2 ;;
      --help|-h) cat <<'EOF'
Usage:
  sshx export NAME [FILE]          Export one connection (stdout if no FILE)
  sshx export --all [FILE]         Export all connections as tar.gz

Options:
  --format sshx|ssh    Output format (default: sshx with metadata)
EOF
        return ;;
      -*)  die "Unknown flag: $1" ;;
      *)
        if ! "$all" && [[ -z "$name" ]]; then
          name="$1"
        else
          file="$1"
        fi
        shift ;;
    esac
  done

  if "$all"; then
    local tmp_dir; tmp_dir=$(mktemp -d)
    local out="${file:-/dev/stdout}"

    cp "$SSHX_CONNECTIONS_DIR"/*.conf "$tmp_dir/" 2>/dev/null || true

    if [[ "$out" == "/dev/stdout" ]]; then
      tar -czf - -C "$tmp_dir" . 2>/dev/null
    else
      tar -czf "$out" -C "$tmp_dir" .
      ok "Exported all connections to '$out'"
    fi
    rm -rf "$tmp_dir"
    return
  fi

  [[ -n "$name" ]] || die "NAME required. Usage: sshx export NAME [FILE]"
  conn_must_exist "$name"

  local src; src=$(conn_file "$name")

  if [[ "$format" == "ssh" ]]; then
    # Strip sshx metadata
    if [[ -n "$file" ]]; then
      grep -v '^# sshx:' "$src" > "$file"
      ok "Exported '$name' (native SSH) to '$file'"
    else
      grep -v '^# sshx:' "$src"
    fi
  else
    if [[ -n "$file" ]]; then
      cp "$src" "$file"
      ok "Exported '$name' to '$file'"
    else
      cat "$src"
    fi
  fi
}

cmd_import() {
  local file="" overwrite=false prefix=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --overwrite) overwrite=true; shift ;;
      --prefix) prefix="$2"; shift 2 ;;
      --help|-h) cat <<'EOF'
Usage: sshx import FILE [options]

Import connections from a sshx export file or native SSH config.

Options:
  --overwrite          Overwrite if name already exists
  --prefix PREFIX      Prepend PREFIX to all imported connection names
EOF
        return ;;
      -*) die "Unknown flag: $1" ;;
      *) file="$1"; shift ;;
    esac
  done

  [[ -n "$file" ]] || die "FILE required."
  [[ -f "$file" ]] || die "File not found: $file"

  local tmp_dir; tmp_dir=$(mktemp -d)
  local imported=0

  # Detect format: tar.gz or single file
  if file "$file" 2>/dev/null | grep -qi "gzip\|tar"; then
    tar -xzf "$file" -C "$tmp_dir" 2>/dev/null
    local src_dir="$tmp_dir"
  else
    cp "$file" "$tmp_dir/"
    local src_dir="$tmp_dir"
  fi

  shopt -s nullglob
  for f in "$src_dir"/*.conf "$src_dir"/*.config; do
    [[ -f "$f" ]] || continue

    local name
    # Try sshx metadata first
    name=$(grep -m1 "^# sshx:name=" "$f" 2>/dev/null | cut -d= -f2-)
    # Fall back to Host directive
    [[ -z "$name" ]] && name=$(grep -m1 "^Host " "$f" 2>/dev/null | awk '{print $2}')
    [[ -z "$name" || "$name" == "*" ]] && continue

    name="${prefix}${name}"
    conn_validate_name "$name" 2>/dev/null || { warn "Skipping invalid name: '$name'"; continue; }

    local dest; dest=$(conn_file "$name")
    if [[ -f "$dest" ]] && ! "$overwrite"; then
      warn "Skipping '$name' — already exists (use --overwrite)"
      continue
    fi

    [[ -f "$dest" ]] && backup_conn "$dest"
    cp "$f" "$dest"
    chmod 600 "$dest"

    # Fix name in file if prefixed
    [[ -n "$prefix" ]] && {
      update_meta "$dest" "name" "$name"
      sed -i "s|^Host .*|Host ${name}|" "$dest"
    }

    local tags; tags=$(conn_meta "$dest" tags)
    _tags_sync "$name" "$tags"
    imported=$((imported+1))
    ok "Imported '$name'"
  done
  shopt -u nullglob

  rm -rf "$tmp_dir"
  ok "Imported $imported connection(s)"
}
