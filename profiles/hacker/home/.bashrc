#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'

_hacker_target_file="${XDG_STATE_HOME:-$HOME/.local/state}/ryoku/lab/target"
if [[ -s "$_hacker_target_file" ]]; then
  IFS= read -r TARGET < "$_hacker_target_file"
  export TARGET
fi

_hacker_prompt() {
  local context="" tun_line tun_ip

  if [[ -s "$_hacker_target_file" ]]; then
    IFS= read -r TARGET < "$_hacker_target_file"
    export TARGET
    context+=" target:$TARGET"
  else
    unset TARGET
  fi

  tun_line=$(ip -4 -o addr show dev tun0 scope global 2>/dev/null || true)
  if [[ -n "$tun_line" ]]; then
    read -r _ _ _ tun_ip _ <<< "$tun_line"
    context+=" tun0:${tun_ip%%/*}"
  fi

  PS1="[\u@\h \W${context}]\\$ "
}

PROMPT_COMMAND="_hacker_prompt${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
_hacker_prompt
