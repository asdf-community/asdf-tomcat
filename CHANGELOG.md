# Changelog

## [2.0.0](https://github.com/asdf-community/asdf-tomcat/compare/v1.0.1...v2.0.0) (2026-11-15)


### ⚠ BREAKING CHANGES

* only catalina.sh is put on PATH, the other scripts of bin (startup.sh, shutdown.sh, version.sh, digest.sh) are not; use "catalina.sh start" and "catalina.sh stop". Versions installed by 1.x keep the whole bin until reinstalled. set-catalina-home.sh does nothing now.

### Features

* Tomcat 11 and later, checksums, catalina.sh only on PATH ([3d6872f](https://github.com/asdf-community/asdf-tomcat/commit/3d6872fc6c19996b72a5644f3d26229a0f072de3))
