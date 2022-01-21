default=docker
if which podman &> /dev/null; then
  default=podman
fi

export DOCKER="${DOCKER:-$default}"
