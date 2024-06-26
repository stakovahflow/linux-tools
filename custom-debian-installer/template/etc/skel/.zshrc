# Set up the prompt

autoload -Uz promptinit
promptinit
# prompt adam1
# prompt dallas
# PS1='%n@%m [%1~] $ '
# PS1='%B%n@%m%b [%T] [%1~] $ '
# PS1='%n@%m [%T] [%B%1~%b] $ '
# PS1='%n@%m [%B%1~%b] $ '
# PS1='%n@%m %~$ '
# PS1='%n@%m %F{red}[%T][%B%~%b]%f$ '

# Red user@host, yellow date, green path:
PS1='%F{red}%B%n@%m%b%f [%F{yellow}%B%T%b%f] [%F{green}%B%1~/%b%f] $ '

setopt histignorealldups sharehistory

# Use emacs keybindings even if our EDITOR is set to vi
bindkey -e

# Keep 1000 lines of history within the shell and save it to ~/.zsh_history:
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history

# Use modern completion system
autoload -Uz compinit
compinit

zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete _correct _approximate
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' menu select=2
eval "$(dircolors -b)"
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=* l:|=*'
zstyle ':completion:*' menu select=long
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle ':completion:*' use-compctl false
zstyle ':completion:*' verbose true

zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'


# Set our path & aliases:

export PATH=$PATH:$HOME/bin
alias ls="ls --color"
alias ll="ls -lh --color"
alias la="ls -Alh --color"
alias lh="ls -lh --color"
alias history='history 1'

# start neofetch
#if [[ -f $(which neofetch) ]]; then neofetch; fi
