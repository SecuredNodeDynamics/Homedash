#!/usr/bin/env bash
# Run beside homedash-pve-package.tar.gz on a Proxmox VE host.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE="${1:-${SCRIPT_DIR}/homedash-pve-package.tar.gz}"

if [[ $# -gt 0 ]]; then
  shift
fi

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this installer as root on the Proxmox VE host." >&2
  exit 1
fi
if [[ ! -f "${PACKAGE}" ]]; then
  echo "Package not found: ${PACKAGE}" >&2
  echo "Usage: bash $(basename "$0") [PACKAGE.tar.gz] [default|advanced]" >&2
  exit 1
fi

CHECKSUM_FILE="${PACKAGE}.sha256"
if [[ -f "${CHECKSUM_FILE}" ]]; then
  echo "Verifying package checksum..."
  expected="$(awk 'NR == 1 { print $1 }' "${CHECKSUM_FILE}")"
  actual="$(sha256sum "${PACKAGE}" | awk '{ print $1 }')"
  if [[ -z "${expected}" || "${actual}" != "${expected}" ]]; then
    echo "Package checksum verification failed." >&2
    exit 1
  fi
  echo "Package checksum verified."
else
  echo "Warning: checksum file not found: ${CHECKSUM_FILE}" >&2
fi

WORK_DIR="$(mktemp -d /tmp/homedash-pve-install.XXXXXX)"
cleanup() { rm -rf "${WORK_DIR}"; }
trap cleanup EXIT HUP INT TERM

tar -xzf "${PACKAGE}" -C "${WORK_DIR}"
INSTALLER="${WORK_DIR}/homedash-pve/install.sh"
if [[ ! -f "${INSTALLER}" ]]; then
  echo "Package does not contain the Homedash PVE installer." >&2
  exit 1
fi

bash "${INSTALLER}" "$@"
