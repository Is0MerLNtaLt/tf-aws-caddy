#!/bin/bash
set -e

readonly SCRIPT_NAME="$(basename "$0")"
readonly SYSTEMD_CONFIG_PATH="/etc/systemd/system/caddy.service"

function print_usage {
  echo
  echo "Usage: install-caddy.sh [OPTIONS]"
  echo
}

function log {
  local readonly level="$1"
  local readonly message="$2"
  local readonly timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  >&2 echo -e "${timestamp} [${level}] [$SCRIPT_NAME] ${message}"
}

function log_info {
  local readonly message="$1"
  log "INFO" "$message"
}

function log_warn {
  local readonly message="$1"
  log "WARN" "$message"
}

function log_error {
  local readonly message="$1"
  log "ERROR" "$message"
}

function assert_not_empty {
  local readonly arg_name="$1"
  local readonly arg_value="$2"

  if [[ -z "$arg_value" ]]; then
    log_error "The value for '$arg_name' cannot be empty"
    print_usage
    exit 1
  fi
}

function user_exists {
  local readonly username="$1"
  id "$username" >/dev/null 2>&1
}

function generate_systemd_config {
  local readonly systemd_config_path="$1"

  log_info "Creating systemd config file to run Caddy in $systemd_config_path"

  local readonly unit_config=$(cat <<EOF
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target

EOF
)

  local readonly service_config=$(cat <<EOF
[Service]
User=caddy
Group=caddy
ExecStart=/usr/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/bin/caddy reload --config /etc/caddy/Caddyfile
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE
EOF
)

  local readonly install_config=$(cat <<EOF
[Install]
WantedBy=multi-user.target
EOF
)

  echo -e "$unit_config" > "$systemd_config_path"
  echo -e "$service_config" >> "$systemd_config_path"
  echo -e "$install_config" >> "$systemd_config_path"
}

function start_caddy {
  log_info "Reloading systemd config and starting Caddy"

  sudo systemctl daemon-reload
  sudo systemctl enable caddy.service
  sudo systemctl restart caddy.service
}

function run {
  generate_systemd_config "$SYSTEMD_CONFIG_PATH"
  start_caddy
}

run "$@"
