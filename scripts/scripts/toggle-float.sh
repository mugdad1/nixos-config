#!/usr/bin/env bash
set -euo pipefail

hyprctl dispatch togglefloating
hyprctl dispatch resizeactive exact 1111 700
hyprctl dispatch centerwindow
