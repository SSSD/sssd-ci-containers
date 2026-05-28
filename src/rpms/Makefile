set-version: prep
	@dnf install -y git
	@if git describe; then \
		GIT_VERSION=$$(git describe | sed 's/-/_/g'); \
		echo "Git describe succeeded. Version: $$GIT_VERSION"; \
		sed -i "s/^Release:.*/Release: $$GIT_VERSION%{?dist}/" $(PWD)/rpmbuild/SPECS/ci-sssd.spec; \
	else \
		echo "Git describe failed with exit code $$?"; \
	fi

prep:
	mkdir -p $(PWD)/rpmbuild/BUILD
	mkdir -p $(PWD)/rpmbuild/RPMS
	mkdir -p $(PWD)/rpmbuild/SOURCES
	mkdir -p $(PWD)/rpmbuild/SPECS
	mkdir -p $(PWD)/rpmbuild/SRPMS
	cp random.c $(PWD)/rpmbuild/SOURCES
	cp sss_pac_responder_client.c $(PWD)/rpmbuild/SOURCES
	cp ci-sssd.spec $(PWD)/rpmbuild/SPECS

srpm: set-version
	rpmbuild --define "_topdir $(PWD)/rpmbuild" -bs $(PWD)/rpmbuild/SPECS/ci-sssd.spec

rpms: set-version
	rpmbuild --define "_topdir $(PWD)/rpmbuild" -ba $(PWD)/rpmbuild/SPECS/ci-sssd.spec

clean:
	rm -fr $(PWD)/rpmbuild
