#!/usr/bin/env bash
set -e

for i in "$@"; do
    tar -xvzf "$i"
    break
done
