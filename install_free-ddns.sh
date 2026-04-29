#!/usr/bin/env bash
set -euo pipefail

# free-ddns installer (self-contained)
#
# Designed to be runnable via:
#   wget -qO- <URL> | bash
# or
#   curl -fsSL <URL> | bash
#
# What it does:
# 1) `go install github.com/17hao/free-ddns@latest`
# 2) copies the built binary to /usr/local/bin/free-ddns (via sudo)
# 3) creates default config at $HOME/.config/free-ddns/config.yaml (if missing)
# 4) writes a systemd unit to /etc/systemd/system/free-ddns.service (via sudo)
# 5) enables/starts free-ddns.service (via sudo)

PROJECT_MODULE="github.com/17hao/free-ddns"
BINARY_NAME="free-ddns"

TARGET_USER="$(id -un)"
TARGET_HOME="${HOME}"

CONFIG_DIR="${TARGET_HOME}/.config/free-ddns"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"

SYSTEMD_UNIT_DST="/etc/systemd/system/free-ddns.service"

usage() {
  cat <<'USAGE'
Usage: install_free-ddns.sh [--no-enable]

Installs free-ddns using `go install`, creates a default config file, and installs
the systemd service.

Options:
  --no-enable   Install the systemd unit but do not enable/start it.
USAGE
}

NO_ENABLE=0
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi
if [[ "${1:-}" == "--no-enable" ]]; then
  NO_ENABLE=1
fi

require_cmd() {
  local c="$1"
  if ! command -v "$c" >/dev/null 2>&1; then
    echo "error: required command not found: $c" >&2
    return 1
  fi
}

write_default_config_if_missing() {
  mkdir -p "${CONFIG_DIR}"
  if [[ -f "${CONFIG_FILE}" ]]; then
    echo "==> Config already exists: ${CONFIG_FILE} (leaving as-is)"
    return 0
  fi

  echo "==> Writing default config: ${CONFIG_FILE}"
  cat >"${CONFIG_FILE}" <<'EOF_CFG'
domainNames: # domain names to be resolved
  - example.com
ipAddressVersion: ipv4 # ipv4 or ipv6
dnsProvider: tencent # tencent or aliyun or cloudflare
credential: # set credentials according to the dns provider
  tencent:
    secretId: xx
    secretKey: xx
  aliyun:
    accessKeyId: xx
    accessKeySecret: xx
  cloudflare:
    token: xxx
EOF_CFG
  chmod 600 "${CONFIG_FILE}" || true
}

write_systemd_unit() {
  echo "==> Installing systemd unit: ${SYSTEMD_UNIT_DST} (requires sudo)"
  # Note: we use sudo + tee so this works even when the script is piped from wget/curl.
  cat <<EOF_UNIT | sudo tee "${SYSTEMD_UNIT_DST}" >/dev/null
[Unit]
Description=free-ddns dynamic DNS updater
Documentation=https://github.com/17hao/free-ddns
After=network-online.target

[Service]
Type=simple
NoNewPrivileges=true
Environment=HOME=$HOME
ExecStart=/usr/local/bin/free-ddns
Restart=on-failure
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
EOF_UNIT
}

main() {
  if ! command -v go >/dev/null 2>&1; then
    cat >&2 <<'EOF_GO'
error: Go toolchain not found ("go" is not in PATH).

Please install Go (https://go.dev/dl/) and ensure $GOPATH/bin is in PATH, then
re-run this installer.
EOF_GO
    exit 1
  fi

  require_cmd sudo
  require_cmd systemctl

  echo "==> Installing ${BINARY_NAME} via go install"
  # Note: This installs to $GOBIN or $GOPATH/bin.
  go install "${PROJECT_MODULE}@latest"

  GOBIN="$(go env GOBIN)"
  if [[ -z "${GOBIN}" ]]; then
    GOBIN="$(go env GOPATH)/bin"
  fi
  INSTALLED_BIN="${GOBIN}/${BINARY_NAME}"

  if [[ ! -x "${INSTALLED_BIN}" ]]; then
    echo "error: go install finished but binary not found at: ${INSTALLED_BIN}" >&2
    exit 1
  fi

  echo "==> Installing binary to /usr/local/bin/${BINARY_NAME} (requires root)"
  sudo install -m 0755 "${INSTALLED_BIN}" "/usr/local/bin/${BINARY_NAME}"

  write_default_config_if_missing

  SERVICE_INSTANCE="free-ddns.service"

  write_systemd_unit
  sudo systemctl daemon-reload
  if [[ ${NO_ENABLE} -eq 0 ]]; then
    sudo systemctl enable --now "${SERVICE_INSTANCE}"
    echo "==> Service enabled and started: ${SERVICE_INSTANCE}"
  else
    echo "==> Unit installed (not enabled): ${SYSTEMD_UNIT_DST}"
    echo "==> To enable later: sudo systemctl enable --now ${SERVICE_INSTANCE}"
  fi

  echo
  echo "All done. Edit your config at: ${CONFIG_FILE}"
  echo "Check status: sudo systemctl status ${SERVICE_INSTANCE}"
}

main "$@"
