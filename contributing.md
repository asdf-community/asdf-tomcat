# Contributing

Lint and format (versions of `shellcheck` and `shfmt` are in `.tool-versions`):

```shell
scripts/lint.bash
scripts/format.bash
```

Testing locally:

```shell
asdf plugin test <plugin-name> <plugin-url> [--asdf-tool-version <version>] [--asdf-plugin-gitref <git-ref>] [test-command*]

asdf plugin test tomcat https://github.com/asdf-community/asdf-tomcat.git "catalina.sh version"
```

Tests are automatically run in GitHub Actions on push and PR.

Commit messages and PR titles follow [Conventional Commits](https://www.conventionalcommits.org):
releases are made by release-please from them.
