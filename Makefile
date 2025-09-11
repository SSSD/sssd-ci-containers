# make build BASE_IMAGE=fedora:latest TAG=latest
build:
	/bin/bash -c "src/build.sh"

# make build REGISTRY=quay.io/account TAG=latest
push:
	/bin/bash -c "src/push.sh"

up:
	/bin/bash -c "src/tools/create-networks.sh"
	docker-compose up --no-recreate --detach ${LIMIT}

up-passkey:
	$(eval HIDRAW := $(shell fido2-token -L | cut -f1 -d:))

	@if [ -z "${HIDRAW}" ]; then \
		echo "🛑 Error: FIDO2 token not found."; \
		exit 1; \
	fi

	@HIDRAW=${HIDRAW} docker-compose -f docker-compose.yml -f docker-compose.passkey.yml up \
	--no-recreate --detach ${LIMIT}

	@docker-compose -f docker-compose.yml -f docker-compose.passkey.yml exec client \
	/usr/bin/setfacl -m u:sssd:rw ${HIDRAW}

# deprecated
up-keycloak:
	docker-compose -f docker-compose.yml up \
	--no-recreate --detach ${LIMIT}

stop:
	docker-compose stop

down:
	docker-compose -f docker-compose.yml \
	-f docker-compose.passkey.yml down
	/bin/bash -c "src/tools/remove-networks.sh"

update:
	docker-compose pull

trust-ca:
	/bin/bash -c "src/tools/trust-ca.sh"

setup-dns:
	/bin/bash -c "src/tools/setup-dns.sh"

setup-dns-files:
	/bin/bash -c "src/tools/setup-dns-files.sh"
