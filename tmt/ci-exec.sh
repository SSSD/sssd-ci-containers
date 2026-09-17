#!/usr/bin/env bash
#
# Execute a script inside one or more sssd-ci-containers.
#
# This is the tmt/Testing Farm counterpart of actions/exec/action.yml so the
# same "run this inside a container" step can be reused from tmt plans.
#
# Usage:
#   ci-exec.sh [options] [-- COMMAND...]
#
# Options:
#   --where "c1 c2"   Space separated list of containers. Default: client
#   --user NAME       User that runs the script.           Default: ci
#   --workdir DIR     Working directory inside container.   Default: /
#   --log FILE        Also store output into FILE.<container>.
#
# The script to run is taken from COMMAND given after -- or, when none is
# given, read from standard input.
#
# Examples:
#   ci-exec.sh --where "client ipa" --user root -- systemctl restart sssd
#
#   ci-exec.sh --where client --user root <<'EOF'
#     dnf install -y sssd
#     systemctl restart sssd
#   EOF
#

set -e -o pipefail

# Container engine. Containers are rootful, so it is always invoked via sudo.
DOCKER="${DOCKER:-podman}"

where="client"
user="ci"
workdir="/"
log=""

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --where)   where="$2";   shift 2 ;;
        --user)    user="$2";    shift 2 ;;
        --workdir) workdir="$2"; shift 2 ;;
        --log)     log="$2";     shift 2 ;;
        --)        shift; break ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if [[ "$#" -gt 0 ]]; then
    script="$*"
else
    script="$(cat)"
fi

# Store the script into a file so it can be copied into the container and run
# by its path. This keeps the shebang honored, just like running any executable.
script_file=$(mktemp)
trap 'rm -f "$script_file"' EXIT
echo "$script" > "$script_file"
chmod 0755 "$script_file"

for container in $where; do
    logfile="/dev/null"
    [[ -n "$log" ]] && logfile="$log.$container"

    echo "# Executing on: $container"
    sudo $DOCKER cp "$script_file" "$container:$script_file"

    rc=0
    sudo $DOCKER exec             \
        --user "$user"            \
        --env "USER=$user"        \
        --workdir "$workdir"      \
        "$container" /bin/bash -c "$script_file" |& tee "$logfile" || rc=$?

    sudo $DOCKER exec --user root "$container" rm -f "$script_file"
    echo "# Finished on: $container"

    [[ $rc -eq 0 ]] || exit $rc
done
