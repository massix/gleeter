#compdef gleeter
# Zsh completion for gleeter

__gleeter_config_file() {
  [[ -n "$GLEETER_CONFIG_FILE" ]] && echo "$GLEETER_CONFIG_FILE" && return
  [[ -n "$XDG_CONFIG_HOME" && -f "$XDG_CONFIG_HOME/gleeter/config.toml" ]] && echo "$XDG_CONFIG_HOME/gleeter/config.toml" && return
  [[ -f "$HOME/.config/gleeter/config.toml" ]] && echo "$HOME/.config/gleeter/config.toml" && return
  [[ -f "./gleeter/config.toml" ]] && echo "./gleeter/config.toml" && return
}

__gleeter_aliases() {
  local config
  config="$(__gleeter_config_file)"
  [[ -f "$config" ]] || return
  awk '
    /^\[\[alias\]\]/{found=1; next}
    /^\[/{found=0}
    found && /^name[[:space:]]*=/{sub(/^name[[:space:]]*=[[:space:]]*"/, ""); sub(/".*$/, ""); gsub(/^[[:space:]]+|[[:space:]]+$/, ""); if ($0 == "") next; if ($0 ~ /[!;$:"()[:space:]]/) next; print}
  ' "$config"
}

_gleeter() {
  local -a commands

  commands=(
    'random:print a random XKCD comic'
    'latest:print the latest XKCD comic'
    'id:print a specific XKCD comic by ID'
    'clearcache:clear the comic cache'
    'serve:start gleeter in server mode'
    'help:show help'
    'version:show version'
  )

  local alias_names
  alias_names="$(__gleeter_aliases)"
  if [[ -n "$alias_names" ]]; then
    while IFS= read -r name; do
      commands+=("${name}:user-defined alias")
    done <<< "$alias_names"
  fi

  _arguments -s \
    '(-n --no-cache)'{-n,--no-cache}'[bypass the comic cache]' \
    '(- *)'{-h,--help}'[show help]' \
    '(- *)'{-v,--version}'[show version]' \
    '1:command:->cmd' \
    '*::arg:->args'

  case $state in
    cmd) _describe 'gleeter command' commands ;;
    args)
      case $words[1] in
        id) _message 'comic ID' ;;
        serve) _arguments '1:port: ' '2:base_path: ' ;;
      esac
      ;;
  esac
}

_gleeter "$@"
