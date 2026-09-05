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

export EDITOR="micro"
export VISUAL="micro"
export NEWT_COLORS='root=white,default:border=white,default:window=white,default:shadow=default,default:title=white,default:button=white,default:actbutton=black,white:checkbox=white,default:actcheckbox=black,white:entry=white,default:label=white,default:listbox=white,default:actlistbox=white,default:sellistbox=black,white:actsellistbox=black,white'
