# https://github.com/fedora-copr/copr/issues/4065 prevents using more precise timestamp
# 
# Builds on the same day will not have determnistic release numbers however
# @sssd/ci-deps does not build multiple times in a single day. Issue occurring
# with build crossing over from 11:59pm to midnight w/ multiple builds is possible but 
# quite unlikely.
%{!?build_timestamp:%global build_timestamp %(date +"%%Y_%%m_%%d")}

Name:           ci-sssd
Version:        1
Release:        2%{?dist}.%{build_timestamp}
Summary:        SSSD CI Packages
URL:            https://github.com/SSSD/sssd-ci-containers

License:        GPLv3+
Source0:        random.c
Source1:        sss_pac_responder_client.c

BuildRequires: gcc
BuildRequires: openssl-devel

%description
SSSD CI Packages. For testing purpose only.

%prep

%build
gcc -fPIC -shared -o random.so %{SOURCE0} -lcrypto
gcc -o sss_pac_responder_client %{SOURCE1} -ldl -lpthread

%install
mkdir -p %{buildroot}/opt
cp random.so  %{buildroot}/opt/random.so
cp sss_pac_responder_client  %{buildroot}/opt/sss_pac_responder_client

%package test-deps
Summary: random.so for passkey testing and sss_pac_responder_client.

%description test-deps
random.so for passkey testing and sss_pac_responder_client.

%files test-deps
/opt/random.so
/opt/sss_pac_responder_client

%changelog
* Mon Oct 06 2023 SSSD Team <sssd-devel@lists.fedorahosted.org> - 1.0.0-2
- sss_pac_responder_client added.

* Thu Jul 20 2023 SSSD Team <sssd-devel@lists.fedorahosted.org> - 1.0.0-1
- Test package release.
