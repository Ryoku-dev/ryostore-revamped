#
# ~/.bash_profile
#

environment_generator=/usr/lib/systemd/user-environment-generators/30-systemd-environment-d-generator
if [[ -x "$environment_generator" ]]; then
  set -a
  eval "$("$environment_generator")"
  set +a
fi

[[ -f ~/.bashrc ]] && . ~/.bashrc
