#!/usr/bin/env bash
set_env_value() {
  local file="$1"
  local key="$2"
  local value="$3"
  local escaped
  escaped="$(printf '%s' "$value" | sed -e 's/[\\/&]/\\&/g')"
  if grep -q "^${key}=" "$file" 2>/dev/null; then
    sed -i.bak "s|^${key}=.*|${key}=${escaped}|" "$file"
    rm -f "${file}.bak"
  else
    printf '%s=%s\n' "$key" "$value" >>"$file"
  fi
}

read_env_value() {
  local file="$1"
  local key="$2"
  [[ -f "$file" ]] || return 0
  sed -n "s/^${key}=//p" "$file" | tail -n 1
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
