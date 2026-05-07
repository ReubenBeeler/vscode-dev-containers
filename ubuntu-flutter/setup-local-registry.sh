#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat >&2 <<'EOF'
Usage: setup-local-registry.sh <command> [<name>] [options]

Commands:
  add    <name> [-p PORT] [--dir DATA_DIR]   Create and start a local registry
  remove <name> [--dir DATA_DIR]             Stop and remove container (--dir also deletes storage)
  list                                        List local registry containers

Options:
  -p PORT        Registry port (default: 5001)
  --dir DIR      Host storage path (default: ~/.local-registry)
EOF
    exit 1
}

parse_opts() {
    PORT=5001
    DATA_DIR="${HOME}/.local-registry"
    DIR_EXPLICIT=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p)    PORT="${2:?'-p' requires a port number}"; shift 2 ;;
            --dir) DATA_DIR="${2:?'--dir' requires a path}"; DIR_EXPLICIT=true; shift 2 ;;
            *)     echo "Unknown option: $1" >&2; usage ;;
        esac
    done
}

cmd_add() {
    local NAME="${1:?'add' requires a registry name}"; shift
    parse_opts "$@"

    mkdir -p "${DATA_DIR}"

    if docker ps -a --format '{{.Names}}' | grep -q "^${NAME}$"; then
        if docker ps --format '{{.Names}}' | grep -q "^${NAME}$"; then
            echo "Registry '${NAME}' is already running at localhost:${PORT}"
        else
            echo "Starting existing registry container '${NAME}'..."
            docker start "${NAME}"
            echo "Registry ready at localhost:${PORT}"
        fi
    else
        if ss -tlnp 2>/dev/null | grep -q ":${PORT}\b" \
           || netstat -tlnp 2>/dev/null | grep -q ":${PORT}\b"; then
            echo "ERROR: Port ${PORT} is already in use by another process." >&2
            echo "Run: ss -tlnp | grep :${PORT}   to identify it." >&2
            exit 1
        fi

        echo "Creating local registry '${NAME}' at localhost:${PORT}..."
        docker run -d \
            --name "${NAME}" \
            --restart unless-stopped \
            -p "${PORT}:5000" \
            -v "${DATA_DIR}:/var/lib/registry" \
            registry:2
        echo "Registry ready at localhost:${PORT}"
    fi

    echo ""
    echo "If docker push fails with 'http: server gave HTTP response to HTTPS client',"
    echo "add this to /etc/docker/daemon.json and restart Docker:"
    echo "  {\"insecure-registries\": [\"localhost:${PORT}\"]}"
}

cmd_remove() {
    local NAME="${1:?'remove' requires a registry name}"; shift
    parse_opts "$@"

    if ! docker ps -a --format '{{.Names}}' | grep -q "^${NAME}$"; then
        echo "No container named '${NAME}' found."
        return 0
    fi

    echo "Stopping and removing '${NAME}'..."
    docker stop "${NAME}" 2>/dev/null || true
    docker rm "${NAME}"
    echo "Container '${NAME}' removed."

    if [[ "${DIR_EXPLICIT}" == true ]]; then
        rm -rf "${DATA_DIR}"
        echo "Deleted data directory: ${DATA_DIR}"
    fi
}

cmd_list() {
    local output
    output="$(docker ps -a --filter ancestor=registry:2 --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}')"
    if [[ "$(echo "$output" | wc -l)" -le 1 ]]; then
        echo "No local registry containers found."
    else
        echo "$output"
    fi
}

COMMAND="${1:-}"
case "$COMMAND" in
    add)    shift; cmd_add "$@" ;;
    remove) shift; cmd_remove "$@" ;;
    list)   cmd_list ;;
    *)      usage ;;
esac
