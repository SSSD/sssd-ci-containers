prep:
	mkdir -p $(PWD)/rpmbuild/BUILD
	mkdir -p $(PWD)/rpmbuild/RPMS
	mkdir -p $(PWD)/rpmbuild/SOURCES
	mkdir -p $(PWD)/rpmbuild/SPECS
	mkdir -p $(PWD)/rpmbuild/SRPMS
	cp random.c $(PWD)/rpmbuild/SOURCES
	cp ci-sssd.spec $(PWD)/rpmbuild/SPECS

srpm: prep
	rpmbuild --define "_topdir $(PWD)/rpmbuild" -bs ci-sssd.spec

rpms: prep
	rpmbuild --define "_topdir $(PWD)/rpmbuild" -ba ci-sssd.spec

clean:
	rm -fr $(PWD)/rpmbuild
