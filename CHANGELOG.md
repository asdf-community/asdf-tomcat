# Changelog

## [2.1.0](https://github.com/asdf-community/asdf-tomcat/compare/v2.0.1...v2.1.0) (2026-11-16)


### Features

* help.config and help.links ([58d5d2a](https://github.com/asdf-community/asdf-tomcat/commit/58d5d2a569788457952ef87b81481d289a6ffb3f))
* version list cache, mirror and checksum settings ([b19119e](https://github.com/asdf-community/asdf-tomcat/commit/b19119ecc8fdcc03e8137e1a7dc9f69ad5809a1a))


### Bug Fixes

* empty the download directory after a failed download ([b19119e](https://github.com/asdf-community/asdf-tomcat/commit/b19119ecc8fdcc03e8137e1a7dc9f69ad5809a1a))

## [2.0.1](https://github.com/asdf-community/asdf-tomcat/compare/v2.0.0...v2.0.1) (2026-11-16)


### Bug Fixes

* compare versions as strings in latest-stable ([3af9de3](https://github.com/asdf-community/asdf-tomcat/commit/3af9de3b3c6d6876387cb3679a54ba12a412f9d1))

## [2.0.0](https://github.com/asdf-community/asdf-tomcat/compare/v1.0.1...v2.0.0) (2026-11-15)


### ⚠ BREAKING CHANGES

* only catalina.sh is put on PATH, the other scripts of bin (startup.sh, shutdown.sh, version.sh, digest.sh) are not; use "catalina.sh start" and "catalina.sh stop". Versions installed by 1.x keep the whole bin until reinstalled. set-catalina-home.sh does nothing now.

### Features

* Tomcat 11 and later, checksums, catalina.sh only on PATH ([3d6872f](https://github.com/asdf-community/asdf-tomcat/commit/3d6872fc6c19996b72a5644f3d26229a0f072de3))
