# make build BASE_IMAGE=fedora:latest TAG=latest
build:
	/bin/bash -c "src/build.sh"

# make build REGISTRY=quay.io/account TAG=latest
push:
	/bin/bash -c "src/push.sh"

up:
	docker-compose up --detach ${LIMIT}

stop:
	docker-compose stop

down:
	docker-compose down

update:
	docker-compose pull

trust-ca:
	/bin/bash -c "src/tools/trust-ca.sh"

setup-dns:
	/bin/bash -c "src/tools/setup-dns.sh"
