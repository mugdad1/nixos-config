#!/usr/bin/env bash

TEMP=4000

if [[ $1 == "toggle" ]]; then
  if pgrep -x hyprsunset > /dev/null; then
    pkill -x hyprsunset
  else
    hyprsunset -t "$TEMP" &
  fi
elif [[ $1 == "status" ]] || [[ -z $1 ]]; then
  if pgrep -x hyprsunset > /dev/null; then
    printf '{"text": "󰛨", "class": "active"}\n'
  else
    printf '{"text": "󰛩", "class": "inactive"}\n'
  fi
fi
