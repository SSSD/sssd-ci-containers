# Third-party files

Vendored binaries used during Windows AD VM provisioning.
Each file has a `.sha256` sidecar for integrity verification:

```console
sha256sum -c <filename>.sha256
```

These packages are vendored rather than fetched at provision time to eliminate
runtime dependencies on external package managers (Chocolatey, PSGallery) and
external CDNs, making provisioning reproducible and air-gap friendly.

**BIND tools** are required because `sssd-test-framework` executes `dig` over SSH
on the Windows AD host to query DNS records during dynamic DNS tests.  Windows
does not ship `dig`; the ISC BIND tools package provides it.

**PSIni** is required by the GPO provisioning tasks that read and write
Group Policy ini-format files (`GptTmpl.inf`, `Registry.pol` sidecars) on the
AD host.  The module is extracted directly from its NuGet package without
needing the NuGet provider or an internet connection.

**OpenSSL** is required by `sssd-test-framework` for smart-card authentication
tests, which perform certificate operations (`pkcs12`, `rsa`, `req`, `genpkey`)
over SSH on the AD host.  The Light installer provides `openssl.exe` and the
shared libraries; the Full installer (with static libs and headers) is not needed.

## Summary

| File | Version | License | Used for |
|------|---------|---------|----------|
| `bind9-toolsonly-9.16.28-x64.zip` | 9.16.28 | MPL-2.0 | `dig` on the AD host |
| `psini-3.1.4.nupkg` | 3.1.4 | MIT | INI file manipulation (GPO tests) |
| `Win64OpenSSL_Light-3_3_7.msi` | 3.3.7 | Apache-2.0 | Certificate operations (smart-card tests) |

---

## bind9-toolsonly-9.16.28-x64.zip

DNS client tools and shared libraries extracted from the official ISC BIND 9.16.28
Windows distribution.  sssd-test-framework runs `dig` over SSH on the AD host to
perform DNS lookups.

Subset of the full ISC zip — excludes `vcredist_x64.exe`, `BINDInstall.exe`,
`Bv9ARM.pdf`, `named.exe`, and changelogs.  `LICENSE` and `COPYRIGHT` are included.

| | |
|---|---|
| **Copyright** | Copyright (C) Internet Systems Consortium, Inc. ("ISC") |
| **License** | `SPDX-License-Identifier: MPL-2.0` |
| **SHA-256 (this zip)** | `e8e184990d064e0924645676b45ce3f382e4d5e1123ebbe7002844234cc088b3` |
| **SHA-256 (upstream zip)** | `72ef760dedb5b2b08ce81cc7f9e7c9ddac4edfa7c8758ee2956d704efc91618f` |
| **Upstream binaries** | <https://ftp.isc.org/isc/bind9/9.16.28/BIND9.16.28.x64.zip> |
| **Source** | <https://gitlab.isc.org/isc-projects/bind9/-/tags/v9_16_28> |
| **License text** | <https://www.mozilla.org/en-US/MPL/2.0/> |

MPL-2.0 permits redistribution of unmodified executables.  Source is available at
the ISC GitLab link above.

---

## psini-3.1.4.nupkg

PSIni PowerShell module (pure PowerShell, no compiled binaries).  Installed into
`C:\Program Files\WindowsPowerShell\Modules\PSIni\3.1.4\` by extracting the nupkg
(a standard zip) directly — no NuGet provider or network access required.

| | |
|---|---|
| **Author** | Oliver Lipkau \<oliver@lipkau.net\> |
| **License** | `SPDX-License-Identifier: MIT` |
| **SHA-256** | `c44f7ded7667ae0ee41e218db9bb194eb2eb524187c9598e779378a1c61bc650` |
| **PSGallery** | <https://www.powershellgallery.com/packages/PSIni/3.1.4> |
| **Source** | <https://github.com/lipkau/PSIni> |

MIT permits unrestricted redistribution.  `LICENSE` is included verbatim in the nupkg.

---

## Win64OpenSSL_Light-3_3_7.msi

OpenSSL Light installer (Shining Light Productions build) for Windows x64.
Installs `openssl.exe` and the OpenSSL shared libraries to
`C:\Program Files\OpenSSL-Win64\`.  Used by sssd-test-framework for certificate
operations (pkcs12, rsa, req, genpkey) during smart-card tests.

| | |
|---|---|
| **Copyright** | Copyright 1998–2024 The OpenSSL Project Authors |
| **License** | `SPDX-License-Identifier: Apache-2.0` |
| **SHA-256** | `22efdec9d2e18d763a3189174c1e4e84b556c75ac89a0ae02cd0f901aeccbbe2` |
| **ProductCode** | `{DDB9F7E3-FB58-456E-B753-546700BDACEB}` |
| **Hash index** | <https://raw.githubusercontent.com/slproweb/opensslhashes/master/win32_openssl_hashes.json> |
| **Upstream installer** | <https://slproweb.com/download/Win64OpenSSL_Light-3_3_7.msi> |
| **Source** | <https://github.com/openssl/openssl/tree/openssl-3.3.7> |
| **License text** | <https://www.apache.org/licenses/LICENSE-2.0> |

Apache-2.0 permits redistribution of unmodified binaries.  The Shining Light
Productions build compiles from official OpenSSL sources without modification.
