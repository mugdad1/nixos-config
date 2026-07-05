#!/usr/bin/env bash
# mcli - NixOS system management

set -euo pipefail

FLAKE_DIR="$HOME/nixos-config"
HOSTNAME=$(hostname)
VERSION="1.0.0"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

usage() {
  cat <<EOF
mcli v${VERSION} - NixOS system management

Usage: mcli <command> [options]

Commands:
  rebuild        Rebuild NixOS configuration
  update         Update flake inputs and rebuild
  diag           System diagnostics
  cleanup        Clean old generations
  trim           SSD TRIM
  help           Show this help

Examples:
  mcli rebuild
  mcli update
  mcli diag
  mcli cleanup
  mcli trim
EOF
}

cmd_rebuild() {
  info "Rebuilding NixOS for ${HOSTNAME}..."
  nh os switch "${FLAKE_DIR}"
  ok "Rebuild complete"
}

cmd_update() {
  info "Updating flake inputs..."
  pushd "${FLAKE_DIR}" >/dev/null
  nix flake update
  popd >/dev/null
  info "Rebuilding with updated inputs..."
  cmd_rebuild
}

cmd_diag() {
  echo -e "${CYAN}=== System Info ===${NC}"
  inxi -S 2>/dev/null || echo "inxi not installed"
  echo ""
  echo -e "${CYAN}=== Memory ===${NC}"
  free -h
  echo ""
  echo -e "${CYAN}=== Disk Usage ===${NC}"
  df -h / /boot 2>/dev/null
  echo ""
  echo -e "${CYAN}=== Nix Store ===${NC}"
  nix store df 2>/dev/null || echo "nix store df not available"
  echo ""
  echo -e "${CYAN}=== Generations ===${NC}"
  nix profile history --profile /nix/var/nix/profiles/system 2>/dev/null | tail -5 || echo "Cannot list generations"
  echo ""
  echo -e "${CYAN}=== NixOS Version ===${NC}"
  nixos-version 2>/dev/null || echo "Not on NixOS"
  echo ""
  echo -e "${CYAN}=== Kernel ===${NC}"
  uname -r
}

cmd_cleanup() {
  local keep=${1:-1}
  info "Cleaning generations (keeping last ${keep})..."
  nh clean all --keep-since 1d --keep "$keep"
  ok "Cleanup complete"
}

cmd_trim() {
  info "Running SSD TRIM..."
  sudo fstrim -av
  ok "TRIM complete"
}

case "${1:-help}" in
  rebuild)  cmd_rebuild ;;
  update)   cmd_update ;;
  diag)     cmd_diag ;;
  cleanup)  cmd_cleanup "${2:-1}" ;;
  trim)     cmd_trim ;;
  help|-h|--help) usage ;;
  *) err "Unknown command: $1"; usage; exit 1 ;;
esac
