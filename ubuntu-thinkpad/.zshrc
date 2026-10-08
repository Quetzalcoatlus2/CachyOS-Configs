if command -v fastfetch >/dev/null 2>&1; then
    fastfetch
fi

setopt autocd
setopt interactivecomments
bindkey -v

export EDITOR=micro
export VISUAL=micro

alias ll='ls -lah'