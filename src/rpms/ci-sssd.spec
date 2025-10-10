%define build_timestamp %(date +"%%Y_%%m_%%d_%%H_%%M_%%S")

Name:           ci-sssd
Version:        1
Release:        1%{?dist}.%{build_timestamp}
Summary:        SSSD CI Packages
URL:            https://github.com/SSSD/sssd-ci-containers

License:        GPLv3+
Source0:        random.c

BuildRequires: gcc
BuildRequires: openssl-devel

%description
SSSD CI Packages. For testing purpose only.

%prep

%build
gcc -fPIC -shared -o random.so %{SOURCE0} -lcrypto

%install
mkdir -p %{buildroot}/opt
cp random.so  %{buildroot}/opt/random.so

%package test-deps
Summary: random.so for passkey testing.

%description test-deps
random.so for passkey testing.

%files test-deps
/opt/random.so

%changelog
* Thu Jul 20 2023 SSSD Team <sssd-devel@lists.fedorahosted.org> - 1.0.0-1
- Test package release.
