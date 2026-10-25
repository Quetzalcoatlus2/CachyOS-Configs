export PATH="$HOME/.local/bin:$PATH"
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

FORCE_COLOR=1 fastfetch 2>/dev/null

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

source /usr/share/cachyos-zsh-config/cachyos-config.zsh

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Overrides the p10k default threshold of 3s (set in ~/.p10k.zsh) so every command shows its duration.
typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD=0

export EDITOR="micro"
export VISUAL="micro"
export NEWT_COLORS='root=white,default:border=white,default:window=white,default:shadow=default,default:title=white,default:button=white,default:actbutton=black,white:checkbox=white,default:actcheckbox=black,white:entry=white,default:label=white,default:listbox=white,default:actlistbox=white,default:sellistbox=black,white:actsellistbox=black,white'
alias xdg-mime='nocorrect xdg-mime'

# Shell workflow enhancements
setopt autocd
setopt interactivecomments
export COLORTERM=truecolor
export HISTORY_IGNORE="(\&|[bf]g|c|clear|history|exit|q|pwd|* --help)"

unalias update 2>/dev/null

function update {
  command paru \
    --pacman /usr/local/bin/pacman-filtered \
    --combinedupgrade \
    --upgrademenu \
    --color always \
    -Syu

  local rc=$?
  pkill -RTMIN+8 -x waybar 2>/dev/null || true
  return "$rc"
}

eval "$(atuin init zsh)"
bindkey -M vicmd '^R' atuin-search
setopt correct_all

# Format man pages with bat syntax highlighting
if command -v bat >/dev/null 2>&1; then
    export MANROFFOPT="-c"
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi

# CachyOS directory, process, and package telemetry aliases
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
alias tarnow='tar -acf '
alias untar='tar -zxvf '
alias wget='wget -c '
alias psmem='ps auxf | sort -nr -k 4'
alias psmem10='ps auxf | sort -nr -k 4 | head -10'
alias big="expac -H M '%m\t%n' | sort -h | nl"
alias rip="expac --timefmt='%Y-%m-%d %T' '%l\t%n %v' | sort | tail -200 | nl"
alias gitpkg='pacman -Q | grep -i "\-git" | wc -l'
alias mirror='sudo cachyos-rate-mirrors'
alias fixpacman='sudo rm /var/lib/pacman/db.lck'
alias cleanup='sudo pacman -Rns $(pacman -Qtdq)'
alias jctl='journalctl -p 3 -xb'
alias tb='nc termbin.com 9999'
