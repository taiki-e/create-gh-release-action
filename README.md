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
      - v[0-9]+.*

jobs:
  create-release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: taiki-e/create-gh-release-action@v1
        with:
          # (optional) Path to changelog.
          changelog: CHANGELOG.md
        env:
          # (required) GitHub token for creating GitHub Releases.
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Example workflow: Custom title

```yaml
name: Release

on:
  push:
    tags:
      - v[0-9]+.*

jobs:
  create-release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: taiki-e/create-gh-release-action@v1
        with:
          # (optional)
          changelog: CHANGELOG.md
          # (optional) Format of title.
          # [default value: $tag]
          # [possible values: variables $tag, $version, and any string]
          title: $version
        env:
          # (required)
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Example workflow: No changelog

```yaml
name: Release

on:
  push:
    tags:
      - v[0-9]+.*

jobs:
  create-release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: taiki-e/create-gh-release-action@v1
        env:
          # (required)
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Other examples

- [cargo-hack](https://github.com/taiki-e/cargo-hack/blob/5d629a8e4b869215acbd55250f078eb211d2337b/.github/workflows/release.yml#L38-L66)
- [pin-project](https://github.com/taiki-e/pin-project/blob/17368bcf3a07d29440d4aa95a7b4384ede9e54f5/.github/workflows/release.yml#L19-L36)

## Configuration

| Input     | Required | Description                                                    | Type   | Default |
|-----------|:--------:|----------------------------------------------------------------|--------|---------|
| changelog | false    | Path to changelog                                              | String |         |
| title     | false    | Format of title (variables `$tag`, `$version`, and any string) | String | `$tag`  |

See [action.yml](action.yml) for more details.

## Related Projects

- [upload-rust-binary-action]: GitHub Action for building and uploading Rust binary to GitHub Releases.
- [parse-changelog]: A simple changelog parser, written in Rust.

[parse-changelog]: https://github.com/taiki-e/parse-changelog
[semver]: https://semver.org
[upload-rust-binary-action]: https://github.com/taiki-e/upload-rust-binary-action

## License

Licensed under either of [Apache License, Version 2.0](LICENSE-APACHE) or
[MIT license](LICENSE-MIT) at your option.

Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in the work by you, as defined in the Apache-2.0 license, shall
be dual licensed as above, without any additional terms or conditions.
