#!/usr/bin/env bash
#
# Install or upgrade Copr packages inside one or more sssd-ci-containers.
#
# It is meant to install the packages freshly built by packit into the running
# containers, but it is generic and works with any Copr project.
#
# Usage:
#   ci-install-copr.sh --where "c1 c2" [--project OWNER/PROJECT] [--packages "p1 p2"]
#
# Options:
#   --where "c1 c2"          Space separated list of containers. Default: client
#   --project OWNER/PROJECT  Copr project to enable.  Default: $PACKIT_COPR_PROJECT
#   --packages "p1 p2"       Packages to install.     Default: $PACKIT_COPR_RPMS
#
# The default project and packages come from the environment set by packit, so
# inside a packit test no arguments beyond --where are needed. For a non-packit
# Copr repository pass both --project and --packages explicitly.
#

set -ex -o pipefail

where="client"
project="${PACKIT_COPR_PROJECT:-}"
packages="${PACKIT_COPR_RPMS:-}"

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --where)    where="$2";    shift 2 ;;
        --project)  project="$2";  shift 2 ;;
        --packages) packages="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$project" ]]; then
    echo "ERROR: No Copr project given, use --project or set PACKIT_COPR_PROJECT." >&2
    exit 1
fi

if [[ -z "$packages" ]]; then
    echo "ERROR: No packages given, use --packages or set PACKIT_COPR_RPMS." >&2
    exit 1
fi

# Prefer the installed ci-exec, fall back to the sibling script when we run
# directly from the repository.
ciexec=$(command -v ci-exec || echo "$(dirname "$(realpath "$0")")/ci-exec.sh")

# The Copr chroot depends on the container distribution, not on the host, so it
# must be detected inside the container. $project and $packages are expanded here
# on the host, everything escaped as \$ is evaluated inside the container.
"$ciexec" --where "$where" --user root <<EOF
set -ex

if ! dnf copr --help &> /dev/null; then
    echo "ERROR: 'dnf copr' is not available, install dnf-plugins-core in the image." >&2
    exit 1
fi

source /etc/os-release
if [[ "\$ID" == "centos" ]]; then
    dnf copr enable -y "$project" "centos-stream-\${VERSION_ID%%.*}-\$(rpm --eval %{_arch})"
else
    dnf copr enable -y "$project"
fi

dnf install -y --refresh --allowerasing $packages
EOF
