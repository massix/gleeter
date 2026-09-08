# Fish completion for gleeter

function __gleeter_config_file
    if set -q GLEETER_CONFIG_FILE; and test -f "$GLEETER_CONFIG_FILE"
        echo "$GLEETER_CONFIG_FILE"
    else if set -q XDG_CONFIG_HOME; and test -f "$XDG_CONFIG_HOME/gleeter/config.toml"
        echo "$XDG_CONFIG_HOME/gleeter/config.toml"
    else if test -f "$HOME/.config/gleeter/config.toml"
        echo "$HOME/.config/gleeter/config.toml"
    else if test -f "./gleeter/config.toml"
        echo "./gleeter/config.toml"
    end
end

function __gleeter_aliases
    set -l config (__gleeter_config_file)
    if test -n "$config"; and test -f "$config"
        awk '
            /^\[\[alias\]\]/{found=1; next}
            /^\[/{found=0}
            found && /^name[[:space:]]*=/{sub(/^name[[:space:]]*=[[:space:]]*"/, ""); sub(/".*$/, ""); gsub(/^[[:space:]]+|[[:space:]]+$/, ""); if ($0 == "") next; if ($0 ~ /[!;$:"()[:space:]]/) next; print}
        ' "$config"
    end
end

complete -c gleeter -f

complete -c gleeter -n '__fish_use_subcommand' -a random -d 'Print a random XKCD comic'
complete -c gleeter -n '__fish_use_subcommand' -a latest -d 'Print the latest XKCD comic'
complete -c gleeter -n '__fish_use_subcommand' -a id -d 'Print a specific XKCD comic by ID'
complete -c gleeter -n '__fish_use_subcommand' -a clearcache -d 'Clear the comic cache'
complete -c gleeter -n '__fish_use_subcommand' -a serve -d 'Start gleeter in server mode'
complete -c gleeter -n '__fish_use_subcommand' -a help -d 'Show help'
complete -c gleeter -n '__fish_use_subcommand' -a version -d 'Show version'

complete -c gleeter -s n -l no-cache -d 'Bypass the comic cache'
complete -c gleeter -s h -l help -d 'Show help'
complete -c gleeter -s v -l version -d 'Show version'

complete -c gleeter -n '__fish_seen_subcommand_from id' -f
complete -c gleeter -n '__fish_seen_subcommand_from serve' -f

for a in (__gleeter_aliases)
    complete -c gleeter -n '__fish_use_subcommand' -a $a -d 'User-defined alias'
end
