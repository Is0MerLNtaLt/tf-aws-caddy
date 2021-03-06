#!/bin/bash
set -e

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

function install_binaries {  
  local -r version="$1"

  curl -OL "https://github.com/caddyserver/caddy/releases/latest/download/caddy_${version}_linux_amd64.tar.gz"
  tar xvzf caddy_${version}_linux_amd64.tar.gz 
  sudo mv caddy /usr/bin/
}

function create_user {
  sudo groupadd --system caddy 
  sudo useradd --system \
    --gid caddy \
    --create-home \
    --home-dir /var/lib/caddy \
    --shell /usr/sbin/nologin \
    --comment "Caddy web server" \
    caddy
}

function place_runner {
    sudo mkdir -p /opt/caddy/bin
    sudo mv "$SCRIPT_DIR/../run-caddy/run-caddy.sh" /opt/caddy/bin
    sudo chown -R "caddy:caddy" /opt/caddy/bin
    sudo chmod a+x /opt/caddy/bin/run-caddy.sh
}

function install {
  local version=""

  while [[ $# > 0 ]]; do
    local key="$1"

    case "$key" in
      --version)
        version="$2"
        shift
        ;;
      --help)
        print_usage
        exit
        ;;
      *)
        log_error "Unrecognized argument: $key"
        print_usage
        exit 1
        ;;
    esac

    shift
  done

  assert_not_empty "--version" "$version"

  log_info "Starting Caddy installation"
  create_user
  install_binaries "$version"
  place_runner
  log_info "Caddy installation complete!"
}

install "$@"
