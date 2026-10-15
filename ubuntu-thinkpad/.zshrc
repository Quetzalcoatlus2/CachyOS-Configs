export PATH="$HOME/.local/bin:$PATH"

if command -v fastfetch >/dev/null 2>&1; then
    fastfetch
fi

setopt autocd
setopt interactivecomments
bindkey -v

export EDITOR=micro
export VISUAL=micro

alias ll='ls -lah'
export COLORTERM=truecolor
[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ] && source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
if command -v atuin >/dev/null 2>&1; then
    eval "$(atuin init zsh)"
    bindkey -M vicmd '^R' atuin-search
fi
