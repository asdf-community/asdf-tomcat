# asdf-tomcat [![Build](https://github.com/asdf-community/asdf-tomcat/actions/workflows/build.yml/badge.svg)](https://github.com/asdf-community/asdf-tomcat/actions/workflows/build.yml) [![Lint](https://github.com/asdf-community/asdf-tomcat/actions/workflows/lint.yml/badge.svg)](https://github.com/asdf-community/asdf-tomcat/actions/workflows/lint.yml)

[Apache Tomcat](https://tomcat.apache.org) plugin for the [asdf version manager](https://asdf-vm.com), also works with [mise](https://mise.jdx.dev).

# Contents

- [Dependencies](#dependencies)
- [Install](#install)
- [Supported versions](#supported-versions)
- [CATALINA_HOME](#catalina_home)
- [Upgrading from 1.x](#upgrading-from-1x)
- [Contributing](#contributing)
- [License](#license)

# Dependencies

- `bash`, `curl`, `tar`: generic POSIX utilities.
- `sha512sum`, `sha1sum`, `md5sum` (Linux) or `shasum`, `md5` (macOS) to verify downloads.
- Java, the version depends on the Tomcat version, see [Which version do I want?](https://tomcat.apache.org/whichversion.html):

| Tomcat | Java         |
|--------|--------------|
| 11.0   | 17 or later  |
| 10.1   | 11 or later  |
| 9.0    | 8 or later   |
| 8.5    | 7 or later   |

# Install

Plugin:

```shell
asdf plugin add tomcat
# or
asdf plugin add tomcat https://github.com/asdf-community/asdf-tomcat.git
```

Tomcat:

```shell
# Show all installable versions
asdf list all tomcat

# Install the latest version, or the latest 9.0.x
asdf install tomcat latest
asdf install tomcat latest:9

# Set a version for the user (~/.tool-versions) or for the current directory
asdf set -u tomcat latest
asdf set tomcat 9.0.124

# Now catalina.sh is available
catalina.sh version
catalina.sh run
```

With mise:

```shell
mise plugins install tomcat https://github.com/asdf-community/asdf-tomcat.git
mise use tomcat@11
```

Check [asdf](https://asdf-vm.com/guide/getting-started.html) documentation for more instructions on how to
install & manage versions.

# Supported versions

Stable releases of Tomcat 6 and later from the [Apache archive](https://archive.apache.org/dist/tomcat/),
new major versions are picked up automatically.
Milestones, betas and release candidates are not listed.

Current releases are downloaded from the Apache CDN (`dlcdn.apache.org`), older ones from the archive.
Every download is verified with the strongest checksum Apache publishes for it (SHA-512, SHA-1 or MD5);
a few very old releases have no checksum and are installed with a warning.

# CATALINA_HOME

Only `catalina.sh` is put on `PATH`: the other scripts in Tomcat's `bin` directory have generic names
(`version.sh`, `startup.sh`, `digest.sh`) and would clash with other tools.
Use `catalina.sh start` and `catalina.sh stop` instead of `startup.sh` and `shutdown.sh`.

`CATALINA_HOME` is set to the selected Tomcat version every time `catalina.sh` runs.
To get the installation directory elsewhere, e.g. for an IDE:

```shell
asdf where tomcat
```

# Upgrading from 1.x

- Versions installed by 1.x keep all scripts of `bin` on `PATH`. Reinstall them to switch to `catalina.sh` only.
- `set-catalina-home.sh` does nothing now and can be removed from the shell profile.
  It exported `CATALINA_HOME` once at shell startup, and after switching to another Tomcat version
  `catalina.sh` kept starting the old one.

# Contributing

Contributions of any kind welcome! See the [contributing guide](contributing.md).

[Thanks goes to these contributors](https://github.com/asdf-community/asdf-tomcat/graphs/contributors)!

# License

See [LICENSE](LICENSE) © [Maxim Butov](https://github.com/mbutov/)
