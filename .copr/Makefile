srpm:
	make -C ./src/rpms srpm
	[ -n "$(outdir)" ] && cp ./rpmbuild/SRPMS/* "$(outdir)" || :
