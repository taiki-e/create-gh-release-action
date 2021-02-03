# create-gh-release-action

GitHub Action for creating GitHub Releases based on changelog.

**Note:**

- This action uses [parse-changelog] to parse changelog.
  Only the changelog format accepted by [parse-changelog] is supported.
- The supported tag format is `v?MAJOR.MINOR.PATCH(-PRERELEASE)?(+BUILD_METADATA)?`.
  (leading "v", pre-release version, and build metadata are optional.)
  This is based on [Semantic Versioning][semver]

## Usage

### Example workflow: Basic usage

```yaml
name: Release

on:
  push:
    tags:
      - v*

jobs:
  create-release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: taiki-e/create-gh-release-action@v1
        with:
          # Path to changelog (optional).
          changelog: CHANGELOG.md
        env:
          # (required) GitHub token for creating GitHub Releases, e.g., `secrets.GITHUB_TOKEN`
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Example workflow: Custom title

```yaml
name: Release

on:
  push:
    tags:
      - v*

jobs:
  create-release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: taiki-e/create-gh-release-action@v1
        with:
          # Format of title (optional) (variables `$tag`, `$version`, and any string, default is `$tag`)
          title: $version
          # Path to changelog (optional).
          changelog: CHANGELOG.md
        env:
          # (required) GitHub token for creating GitHub Releases, e.g., `secrets.GITHUB_TOKEN`
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Example workflow: No changelog

```yaml
name: Release

on:
  push:
    tags:
      - v*

jobs:
  create-release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: taiki-e/create-gh-release-action@v1
        env:
          # (required) GitHub token for creating GitHub Releases, e.g., `secrets.GITHUB_TOKEN`
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Configuration

| Input     | Required | Description                                                              | Type   | Default        |
|-----------|:--------:|--------------------------------------------------------------------------|--------|:--------------:|
| title     | false    | Format of title (variables `$tag`, `$version`, and any string)           | String | `$tag`         |
| changelog | false    | Path to changelog                                                        | String |                |

See [action.yml](action.yml) for more details.

[parse-changelog]: https://github.com/taiki-e/parse-changelog
[semver]: https://semver.org

## License

Licensed under either of [Apache License, Version 2.0](LICENSE-APACHE) or
[MIT license](LICENSE-MIT) at your option.

Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in the work by you, as defined in the Apache-2.0 license, shall
be dual licensed as above, without any additional terms or conditions.
