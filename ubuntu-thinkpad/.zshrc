export PATH="$HOME/.local/bin:$PATH"

if command -v fastfetch >/dev/null 2>&1; then
    FORCE_COLOR=1 fastfetch 2>/dev/null
fi

typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.local/share/oh-my-zsh"
DISABLE_MAGIC_FUNCTIONS="true"
COMPLETION_WAITING_DOTS="true"
plugins=(git fzf extract)
ENABLE_CORRECTION="true"
source "$ZSH/oh-my-zsh.sh"

source "$HOME/.local/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme"

[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ] && source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[ -f "$HOME/.local/share/zsh-history-substring-search/zsh-history-substring-search.zsh" ] && source "$HOME/.local/share/zsh-history-substring-search/zsh-history-substring-search.zsh"

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Overrides the p10k default threshold of 3s so every command shows its duration.
typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD=0

export EDITOR=micro
export VISUAL=micro
export NEWT_COLORS='root=white,default:border=white,default:window=white,default:shadow=default,default:title=white,default:button=white,default:actbutton=black,white:checkbox=white,default:actcheckbox=black,white:entry=white,default:label=white,default:listbox=white,default:actlistbox=white,default:sellistbox=black,white:actsellistbox=black,white'
alias xdg-mime='nocorrect xdg-mime'
alias ll='ls -lah'
export COLORTERM=truecolor
export LESS_TERMCAP_md="$(tput bold 2> /dev/null; tput setaf 2 2> /dev/null)"
export LESS_TERMCAP_me="$(tput sgr0 2> /dev/null)"
export HISTORY_IGNORE="(\&|[bf]g|c|clear|history|exit|q|pwd|* --help)"

setopt autocd
setopt interactivecomments

unalias update 2>/dev/null
update() {
    sudo apt update && sudo apt upgrade
}

if command -v atuin >/dev/null 2>&1; then
    eval "$(atuin init zsh)"
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
alias make="make -j$(nproc)"
alias ninja="ninja -j$(nproc)"
alias n="ninja"
alias c="clear"
alias please="sudo"
