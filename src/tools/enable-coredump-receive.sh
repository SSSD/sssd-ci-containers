#!/bin/bash
#
# Enable systemd coredump forwarding (CoredumpReceive=) for all currently
# running sssd-ci-containers containers, so that a crash inside a container
# is picked up by the systemd-coredump running *inside* that container
# instead of (only) on the host.
#
# Requires: podman with the systemd cgroup manager (the project default),
# host systemd >= 255, and root privileges (rootful podman containers run
# their scopes under the system instance).
#
# Usage:
#   enable-coredump-receive.sh [-f COMPOSE_FILE ...]
#
# Any arguments are forwarded to "<engine> compose ... ps" so that the correct
# set of containers is enumerated regardless of which compose file set was used
# to bring the stack up (e.g. the passkey or keycloak overrides).
#

# This script is needed until https://github.com/podman-container-tools/podman/issues/22958 is resolved

set -uo pipefail

pushd "$(realpath "$(dirname "$0")")/../.." &> /dev/null

systemd_version=$(systemctl --version | head -1 | awk '{print $2}')
if [ "${systemd_version%%.*}" -lt 255 ] 2>/dev/null; then
    echo "Warning: skipping coredump forwarding setup, this requires systemd >= 255 (found: $systemd_version)." >&2
    popd &> /dev/null
    exit 0
fi

if [ "$(stat -fc %T /sys/fs/cgroup 2>/dev/null)" != "cgroup2fs" ]; then
    echo "Warning: skipping coredump forwarding setup, this requires the unified cgroups v2 hierarchy." >&2
    popd &> /dev/null
    exit 0
fi

source src/tools/get-container-engine.sh

if [ "$DOCKER" != "podman" ]; then
    echo "Error: this only works with podman (found engine: $DOCKER)." >&2
    exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: this script must be run as root (rootful podman scopes" >&2
    echo "are managed by the system systemd instance)." >&2
    exit 1
fi

# When SELinux is enforcing, the host systemd-coredump is not allowed to
# connect to the container's /run/systemd/coredump socket, so the forwarded
# dump silently falls back to the host. Install a small policy module that
# grants just that one permission. Idempotent: only installs if missing.
selinux_module="coredump-to-container"
if command -v getenforce &> /dev/null && [ "$(getenforce)" = "Enforcing" ]; then
    if ! semodule -l 2>/dev/null | grep -qx "$selinux_module"; then
        echo "Installing SELinux module '$selinux_module' (allows coredump forwarding into containers)"
        semodule -i "src/tools/${selinux_module}.cil" \
            || echo "Warning: failed to install SELinux module '$selinux_module', coredump forwarding may be blocked by SELinux." >&2
    fi
fi

mapfile -t CIDS < <("$DOCKER" compose "$@" ps -q 2>/dev/null)

if [ "${#CIDS[@]}" -eq 0 ]; then
    echo "No containers found for this compose project." >&2
    exit 1
fi

changed=0
for cid in "${CIDS[@]}"; do
    id=$(podman inspect -f '{{.Id}}' "$cid" 2>/dev/null) || continue
    name=$(podman inspect -f '{{.Name}}' "$id" | sed 's#^/##')
    running=$(podman inspect -f '{{.State.Running}}' "$id")

    if [ "$running" != "true" ]; then
        echo "Skipping $name: not running"
        continue
    fi

    scope=$(podman inspect -f '{{.State.CgroupPath}}' "$id" | sed 's#.*/##')

    if [ -z "$scope" ] || ! systemctl list-units --all --no-legend "$scope" | grep -q "$scope"; then
        echo "Skipping $name: could not find a systemd scope (is podman using the systemd cgroup manager?)"
        continue
    fi

    # CoredumpReceive= only has an effect together with Delegate=yes. podman
    # already sets Delegate=yes on the container scope; if for some reason it
    # isn't set we can't add it at runtime, so just skip.
    if [ "$(systemctl show -p Delegate --value "$scope")" != "yes" ]; then
        echo "Skipping $name: scope is not delegated (Delegate=yes), cannot enable coredump forwarding"
        continue
    fi

    # CoredumpReceive= is a transient-only property: it cannot be changed on an
    # already-running unit via 'systemctl set-property'. Instead we write a
    # config drop-in and reload below - daemon-reload re-parses the unit config
    # and re-realizes its cgroup, which stamps the user.coredump_receive xattr
    # that systemd-coredump reads (live, at crash time) to decide whether to
    # forward the dump into the container. The drop-in lives under /run so it is
    # discarded on reboot, matching the ephemeral nature of podman scopes.
    dropin_dir="/run/systemd/system/${scope}.d"
    mkdir -p "$dropin_dir"
    printf '[Scope]\nCoredumpReceive=yes\n' > "$dropin_dir/50-coredump-receive.conf"
    echo "Enabling CoredumpReceive on $name ($scope)"
    changed=1
done

if [ "$changed" -eq 1 ]; then
    systemctl daemon-reload
fi

popd &> /dev/null
