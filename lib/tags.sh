#!/usr/bin/env bash
# lib/tags.sh — tag CRUD with symlink tracking

# Internal: sync symlinks for a connection's tags
_tags_sync() {
  local name="$1"
  local tags_str="$2"
  local file; file=$(conn_file "$name")

  # Remove old symlinks for this connection
  _tags_remove_all "$name"

  [[ -z "$tags_str" ]] && return

  # Create new symlinks: ~/.sshx/tags/TAG/name -> ../../config.d/name.conf
  IFS=',' read -ra tag_arr <<< "$tags_str"
  for tag in "${tag_arr[@]}"; do
    tag="${tag// /}"  # strip spaces
    [[ -z "$tag" ]] && continue
    local tag_dir="$SSHX_TAGS_DIR/$tag"
    mkdir -p "$tag_dir"
    local rel_target="../../config.d/${name}.conf"
    ln -sf "$rel_target" "$tag_dir/${name}"
  done
}

# Internal: remove all tag symlinks for a connection
_tags_remove_all() {
  local name="$1"
  [[ -d "$SSHX_TAGS_DIR" ]] || return 0
  find "$SSHX_TAGS_DIR" -name "$name" -type l -delete 2>/dev/null || true
  # Clean empty tag dirs
  find "$SSHX_TAGS_DIR" -mindepth 1 -maxdepth 1 -type d -empty -delete 2>/dev/null || true
}

# ─── tag add ─────────────────────────────────────────────────────────────────

cmd_tag_add() {
  [[ $# -ge 2 ]] || die "Usage: sshx tag add NAME TAG[,TAG2,...]"
  local name="$1" new_tags_str="$2"
  conn_must_exist "$name"

  local file; file=$(conn_file "$name")
  local current; current=$(conn_meta "$file" tags)

  # Merge tags, deduplicate
  local merged
  IFS=',' read -ra existing_arr <<< "$current"
  IFS=',' read -ra new_arr <<< "$new_tags_str"
  local -A seen=()
  local merged_arr=()
  for t in "${existing_arr[@]}" "${new_arr[@]}"; do
    t="${t// /}"
    [[ -z "$t" || -n "${seen[$t]:-}" ]] && continue
    seen[$t]=1
    merged_arr+=("$t")
  done
  merged=$(IFS=','; echo "${merged_arr[*]}")

  backup_conn "$file"
  update_meta "$file" "tags" "$merged"
  touch_updated "$file"
  _tags_sync "$name" "$merged"
  ok "Tags for '$name': $merged"
}

# ─── tag remove ──────────────────────────────────────────────────────────────

cmd_tag_remove() {
  [[ $# -ge 2 ]] || die "Usage: sshx tag remove NAME TAG[,TAG2,...]"
  local name="$1" rm_tags_str="$2"
  conn_must_exist "$name"

  local file; file=$(conn_file "$name")
  local current; current=$(conn_meta "$file" tags)

  IFS=',' read -ra existing_arr <<< "$current"
  IFS=',' read -ra rm_arr <<< "$rm_tags_str"
  local -A to_remove=()
  for t in "${rm_arr[@]}"; do to_remove[${t// /}]=1; done

  local -a keep=()
  for t in "${existing_arr[@]}"; do
    t="${t// /}"
    [[ -z "$t" || -n "${to_remove[$t]:-}" ]] && continue
    keep+=("$t")
  done
  local merged
  merged=$(IFS=','; echo "${keep[*]}")

  backup_conn "$file"
  update_meta "$file" "tags" "$merged"
  touch_updated "$file"
  _tags_sync "$name" "$merged"
  ok "Tags for '$name': ${merged:-<none>}"
}

# ─── tag list ────────────────────────────────────────────────────────────────

cmd_tag_list() {
  [[ -d "$SSHX_TAGS_DIR" ]] || { info "No tags found."; return; }

  local -A tag_counts=()
  for f in $(conn_files); do
    local tags; tags=$(conn_meta "$f" tags)
    [[ -z "$tags" ]] && continue
    IFS=',' read -ra arr <<< "$tags"
    for t in "${arr[@]}"; do
      t="${t// /}"
      [[ -n "$t" ]] && tag_counts[$t]=$(( ${tag_counts[$t]:-0} + 1 ))
    done
  done

  [[ ${#tag_counts[@]} -gt 0 ]] || { info "No tags found."; return; }

  {
    printf 'TAG\tCONNECTIONS\n'
    for tag in $(printf '%s\n' "${!tag_counts[@]}" | sort); do
      printf '%s\t%s\n' "$tag" "${tag_counts[$tag]}"
    done
  } | print_table
}

# ─── tag rename ──────────────────────────────────────────────────────────────

cmd_tag_rename() {
  [[ $# -ge 2 ]] || die "Usage: sshx tag rename OLD NEW"
  local old="$1" new="$2"

  local count=0
  for f in $(conn_files); do
    local tags; tags=$(conn_meta "$f" tags)
    [[ "$tags" == *"$old"* ]] || continue

    # Replace old tag with new
    local new_tags
    new_tags=$(echo "$tags" | sed "s/\(^\|,\)${old}\(,\|$\)/\1${new}\2/g")
    backup_conn "$f"
    update_meta "$f" "tags" "$new_tags"
    touch_updated "$f"
    local name; name=$(conn_meta "$f" name)
    _tags_sync "$name" "$new_tags"
    count=$((count+1))
  done

  [[ $count -gt 0 ]] || warn "Tag '$old' not found on any connection."
  ok "Renamed tag '$old' → '$new' on $count connection(s)"
}
