# make build BASE_IMAGE=fedora:latest TAG=latest
build:
	/bin/bash -c "src/build.sh"

# make build REGISTRY=quay.io/account TAG=latest
push:
	/bin/bash -c "src/push.sh"

up:
	# It is important to use podman-compose instead of docker-compose now.
	# docker-compose creates additional networks with isolation = True.
	# podman-compose creates additional networks with isolation = False
	podman-compose up --no-recreate --detach ${LIMIT}

up-passkey:
	export HIDRAW=$(shell fido2-token -L|cut -f1 -d:) \
	&& podman-compose -f podman-compose.yml -f podman-compose.passkey.yml up \
	--no-recreate --detach ${LIMIT}

up-keycloak:
	podman-compose -f podman-compose.yml -f podman-compose.keycloak.yml up \
	--no-recreate --detach ${LIMIT}

stop:
	podman-compose stop

down:
	podman-compose -f podman-compose.yml \
	-f podman-compose.keycloak.yml \
	-f podman-compose.passkey.yml down

update:
	podman-compose pull

trust-ca:
	/bin/bash -c "src/tools/trust-ca.sh"

setup-dns:
	/bin/bash -c "src/tools/setup-dns.sh"

setup-dns-files:
	/bin/bash -c "src/tools/setup-dns-files.sh"
