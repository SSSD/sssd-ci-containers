#!/usr/bin/env bash
#
# Setup and start sssd-ci-containers on the current host.
#
# This is the tmt/Testing Farm counterpart of actions/setup/action.yml so the
# container environment can be brought up the same way from a tmt plan
# (prepare: how: shell, url: <this repo>).
#
# It works on Fedora/CentOS (as run under Testing Farm) and on Debian/Ubuntu
# (as run in GitHub Actions). The containers are rootful, so privileged commands
# always run via sudo (root is expected to be able to sudo).
#
# Configuration is taken from the environment, all values are optional:
#   REGISTRY   Image registry.                   Default: quay.io/sssd
#   TAG        Image tag to pull.                Default: deduced from the
#              packit copr build (.fcNN/.elNN), or fedora-latest otherwise.
#   LIMIT      Space separated services to run.  Default: all
#   OVERRIDE   docker-compose override content.  Default: repository default
#

set -ex -o pipefail

REGISTRY="${REGISTRY:-quay.io/sssd}"
LIMIT="${LIMIT:-}"
OVERRIDE="${OVERRIDE:-}"

function retry {
    local count=$1
    shift  # Remove count from arguments
    shift  # Remove the '--' separator
    local cmd=("$@")

    local attempt=1
    while [[ $attempt -le $count ]]; do
        if "${cmd[@]}"; then
            return 0
        fi

        if [[ $attempt -lt $count ]]; then
            echo "ERROR: Command failed, retrying..." >&2
            ((attempt++))
        else
            echo "ERROR: All $count attempts failed." >&2
            return 1
        fi
    done
}

# Deduce the container image tag from the packit copr build unless TAG is set.
# The build target is not exposed by packit directly, but the built rpms carry
# the dist tag (.fcNN, .elNN) which identifies the distribution. When there is a
# packit build we must be able to deduce the tag from it, otherwise we fail. Only
# without any packit build (e.g. run manually) we fall back to fedora-latest.
function get_tag {
    local rpms="${PACKIT_COPR_RPMS:-${PACKIT_PACKAGE_NVR:-}}"
    if [[ -z "$rpms" ]]; then
        echo "fedora-latest"
    elif [[ "$rpms" =~ \.fc([0-9]+) ]]; then
        echo "fedora-${BASH_REMATCH[1]}"
    elif [[ "$rpms" =~ \.el([0-9]+) ]]; then
        echo "centos-${BASH_REMATCH[1]}"
    else
        echo "ERROR: unable to deduce container tag from packit build: $rpms" >&2
        exit 1
    fi
}
TAG="${TAG:-$(get_tag)}"

DOCKER_HOST="unix:///run/podman/podman.sock"
export REGISTRY TAG DOCKER_HOST

repo=$(realpath "$(dirname "$0")/..")

echo "# Using container tag: $TAG"

# Detect the distribution family to pick the package manager and ca-trust tool.
source /etc/os-release
case " $ID ${ID_LIKE:-} " in
    *" debian "*) family="debian" ;;
    *)            family="redhat" ;;
esac

echo "# Install dependencies"
if [[ "$family" == "debian" ]]; then
    sudo apt-get update
    sudo apt-get install -y make podman docker-compose
else
    if [[ "$ID" == "centos" ]]; then
        sudo dnf install -y epel-release
    fi
    sudo dnf install -y make podman docker-compose podman-docker
fi

echo "# Install helper scripts"
sudo install -m 0755 "$repo/tmt/ci-exec.sh"         /usr/local/bin/ci-exec
sudo install -m 0755 "$repo/tmt/ci-install-copr.sh" /usr/local/bin/ci-install-copr
sudo install -m 0755 "$repo/tmt/ci-select-tests.sh" /usr/local/bin/ci-select-tests

echo "# Start podman socket"
sudo systemctl enable --now podman.socket

echo "# Add docker-compose override"
if [[ -n "$OVERRIDE" ]]; then
    echo "$OVERRIDE" > "$repo/docker-compose.override.yml"
    cat "$repo/docker-compose.override.yml"
else
    echo "No override provided, keeping repository default."
fi

echo "# Setup DNS"
sudo make -C "$repo" setup-dns-files

echo "# Trust container CA"
if [[ "$family" == "debian" ]]; then
    sudo cp "$repo/data/certs/ca.crt" /usr/local/share/ca-certificates/sssd-ci-containers.crt
    sudo update-ca-certificates
else
    sudo cp "$repo/data/certs/ca.crt" /etc/pki/ca-trust/source/anchors/sssd-ci-containers.crt
    sudo update-ca-trust
fi

echo "# Print docker-compose config"
podman compose --project-directory "$repo" config

echo "# Start containers"
retry 5 -- sudo make -C "$repo" up DOCKER_HOST="$DOCKER_HOST" LIMIT="$LIMIT" REGISTRY="$REGISTRY" TAG="$TAG"
