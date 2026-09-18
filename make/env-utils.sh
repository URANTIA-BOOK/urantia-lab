#!/usr/bin/env bash
# Rewrite KEY=value lines without sed. Paths like /v1 and URLs with slashes
# must survive GNU and BSD sed; a newline in a $(chooser) must not become
# an unterminated s/// command.

_rewrite_env_key() {
  local file="$1"
  local mode="$2"
  local key="$3"
  local value="${4:-}"
  local tmp line found=false
  tmp="$(mktemp)"
  [[ -f "$file" ]] || : >"$file"
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == "${key}="* ]]; then
      if [[ "$mode" == "set" && "$found" != "true" ]]; then
        printf '%s=%s\n' "$key" "$value"
        found=true
      fi
    else
      printf '%s\n' "$line"
    fi
  done <"$file" >"$tmp"
  if [[ "$mode" == "set" && "$found" != "true" ]]; then
    printf '%s=%s\n' "$key" "$value" >>"$tmp"
  fi
  mv "$tmp" "$file"
}

set_env_value() {
  local file="$1"
  local key="$2"
  local value="$3"
  if [[ "$value" == *$'\n'* ]]; then
    echo "env value for $key must be a single line" >&2
    return 1
  fi
  _rewrite_env_key "$file" set "$key" "$value"
}

read_env_value() {
  local file="$1"
  local key="$2"
  [[ -f "$file" ]] || return 0
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == "${key}="* ]]; then
      printf '%s\n' "${line#${key}=}"
    fi
  done <"$file" | tail -n 1
}

unset_env_value() {
  local file="$1"
  local key="$2"
  [[ -f "$file" ]] || return 0
  _rewrite_env_key "$file" unset "$key"
}

ensure_secret() {
  local file="$1"
  local key="$2"
  local current
  current="$(read_env_value "$file" "$key")"
  if [[ -z "$current" ]]; then
    set_env_value "$file" "$key" "$(openssl rand -hex 24)"
  fi
}
