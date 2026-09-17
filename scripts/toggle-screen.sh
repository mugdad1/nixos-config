#!/usr/bin/env bash
set -euo pipefail

# toggle all outputs' power (DPMS off/on) without sleeping the machine
wlopm --toggle "*"