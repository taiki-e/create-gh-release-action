# create-gh-release-action

GitHub Action for creating GitHub Releases based on changelog.

<!-- TOC depthfrom:2 -->

- [Usage](#usage)
  - [Inputs](#inputs)
  - [Example workflow: Basic usage](#example-workflow-basic-usage)
  - [Example workflow: Custom title](#example-workflow-custom-title)
  - [Example workflow: No changelog](#example-workflow-no-changelog)
  - [Other examples](#other-examples)
- [Related Projects](#related-projects)
- [License](#license)

<!-- /TOC -->

## Usage

This action creates GitHub Releases based on changelog that specified by `changelog` option.

Currently, changelog format and supported tag names have the following rule:

- This action uses [parse-changelog] to parse changelog.
  Only the changelog format accepted by [parse-changelog] is supported.

  Basically, [Keep a Changelog][keepachangelog] and similar formats are
  supported, but we recommend checking if [parse-changelog] can parse your
  project's changelog as you expected.

  [If the `changelog` option is not specified, the changelog is ignored and only the release created.](#example-workflow-no-changelog)

- The supported tag format is `v?MAJOR.MINOR.PATCH(-PRERELEASE)?(+BUILD_METADATA)?`.
  (leading "v", pre-release version, and build metadata are optional.)
  This is based on [Semantic Versioning][semver]

### Inputs

| Name     | Required | Description                                                    | Type   | Default |
|-----------|:--------:|----------------------------------------------------------------|--------|---------|
| changelog | false    | Path to changelog                                              | String |         |
| title     | false    | Format of title (variables `$tag`, `$version`, and any string) | String | `$tag`  |

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

You can customize the title of the release by `title` option.

*[Example of the created release.](https://github.com/taiki-e/pin-project/releases/tag/v1.0.4)*

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

If the `changelog` option is not specified, the changelog is ignored and only the release created.

*[Example of the created release.](https://github.com/openrr/urdf-viz/releases/tag/v0.23.1)*

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

- [pin-project/.github/workflows/release.yml](https://github.com/taiki-e/pin-project/blob/17368bcf3a07d29440d4aa95a7b4384ede9e54f5/.github/workflows/release.yml#L19-L36)
- [urdf-viz/.github/workflows/release.yml](https://github.com/openrr/urdf-viz/blob/d6f16cbdda66a54a55ac2f14ac0c69819127b2d4/.github/workflows/release.yml#L29-L31)

## Related Projects

- [upload-rust-binary-action]: GitHub Action for building and uploading Rust binary to GitHub Releases.
- [parse-changelog]: A simple changelog parser, written in Rust. Used in this action.

[keepachangelog]: https://keepachangelog.com/en/1.0.0
[parse-changelog]: https://github.com/taiki-e/parse-changelog
[semver]: https://semver.org
[upload-rust-binary-action]: https://github.com/taiki-e/upload-rust-binary-action

## License

Licensed under either of [Apache License, Version 2.0](LICENSE-APACHE) or
[MIT license](LICENSE-MIT) at your option.

Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in the work by you, as defined in the Apache-2.0 license, shall
be dual licensed as above, without any additional terms or conditions.
