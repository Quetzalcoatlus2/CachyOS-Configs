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

# Portable CachyOS Zsh enhancements and aliases
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt appendhistory sharehistory hist_ignore_space hist_ignore_all_dups hist_save_no_dups hist_find_no_dups

if command -v batcat >/dev/null 2>&1; then
    export MANROFFOPT="-c"
    export MANPAGER="sh -c 'col -bx | batcat -l man -p'"
elif command -v bat >/dev/null 2>&1; then
    export MANROFFOPT="-c"
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi

if command -v eza >/dev/null 2>&1; then
    alias ls='eza -al --color=always --group-directories-first --icons'
    alias la='eza -a --color=always --group-directories-first --icons'
    alias ll='eza -l --color=always --group-directories-first --icons'
    alias lt='eza -aT --color=always --group-directories-first --icons'
    alias l.="eza -a | grep -e '^\.'"
fi

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias grep='grep --color=auto'
alias tarnow='tar -acf '
alias untar='tar -zxvf '
alias wget='wget -c '
alias psmem='ps auxf | sort -nr -k 4'
alias psmem10='ps auxf | sort -nr -k 4 | head -10'
alias jctl='journalctl -p 3 -xb'
alias tb='nc termbin.com 9999'
alias cleanup='sudo apt autoremove -y'

# Right-side clock (HH:MM:SS).
RPROMPT='%D{%H:%M:%S}'
