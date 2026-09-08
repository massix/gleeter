#!/usr/bin/env bash
# Bash completion for gleeter

__gleeter_config_file() {
  [ -n "$GLEETER_CONFIG_FILE" ] && echo "$GLEETER_CONFIG_FILE" && return
  [ -n "$XDG_CONFIG_HOME" ] && [ -f "$XDG_CONFIG_HOME/gleeter/config.toml" ] && echo "$XDG_CONFIG_HOME/gleeter/config.toml" && return
  [ -f "$HOME/.config/gleeter/config.toml" ] && echo "$HOME/.config/gleeter/config.toml" && return
  [ -f "./gleeter/config.toml" ] && echo "./gleeter/config.toml" && return
  echo ""
}

__gleeter_aliases() {
  local config
  config="$(__gleeter_config_file)"
  [ -f "$config" ] || return 0
  awk '
    /^\[\[alias\]\]/{found=1; next}
    /^\[/{found=0}
    found && /^name[[:space:]]*=/{sub(/^name[[:space:]]*=[[:space:]]*"/, ""); sub(/".*$/, ""); gsub(/^[[:space:]]+|[[:space:]]+$/, ""); if ($0 == "") next; if ($0 ~ /[!;$:"()[:space:]]/) next; print}
  ' "$config"
}

_gleeter() {
  local cur prev
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  local commands="random latest id clearcache serve help version"
  local flags="--no-cache -n --help --version"

  if [ "$prev" = "id" ] || [ "$prev" = "serve" ]; then
    return
  fi

  local all=("${commands[@]}" "${flags[@]}")
  local aliases
  aliases=$(__gleeter_aliases)
  if [ -n "$aliases" ]; then
    while IFS= read -r a; do all+=("$a"); done <<< "$aliases"
  fi

  COMPREPLY=($(compgen -W "${all[*]}" -- "$cur"))
}

complete -F _gleeter gleeter
