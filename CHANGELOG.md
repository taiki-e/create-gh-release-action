# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org).

<!--
Note: In this file, do not use the hard wrap in the middle of a sentence for compatibility with GitHub comment style markdown rendering.
-->

## [Unreleased]

## [1.6.3] - 2023-03-19

- Diagnostics improvements.

## [1.6.2] - 2022-12-24

- Support self-hosted runner that does not set `GITHUB_OUTPUT` environment variable. ([#17](https://github.com/taiki-e/create-gh-release-action/pull/17))

## [1.6.1] - 2022-10-14

- Fix invalid version format check introduced in 1.4.0.

- Remove uses of [deprecated set-output workflow commands](https://github.blog/changelog/2022-10-11-github-actions-deprecating-save-state-and-set-output-commands).

## [1.6.0] - 2022-09-08

- Add `token` input option to use the specified token instead of `GITHUB_TOKEN` environment variable.

- Add `ref` input option to use the specified tag ref instead of `GITHUB_REF` environment variable.

- Update `parse-changelog` to 0.5.1. This includes a bug fix and performance improvements.

## [1.5.0] - 2022-02-17

- Set `computed-prefix` and `version` outputs. ([#12](https://github.com/taiki-e/create-gh-release-action/pull/12), thanks @sunshowers)

- Update default runtime to node16.

## [1.4.0] - 2021-12-25

- Fix handling of trailing hyphen in prefix. ([#10](https://github.com/taiki-e/create-gh-release-action/pull/10))

- Warn version that invalid as semver. ([#11](https://github.com/taiki-e/create-gh-release-action/pull/11))

  They will be rejected in the next major version.

## [1.3.0] - 2021-12-21

- Add support for a custom tag prefix ([#8](https://github.com/taiki-e/create-gh-release-action/pull/8), thanks @hawkw)

## [1.2.2] - 2021-07-24

- Update `parse-changelog` to 0.4.3. This includes a bug fix and performance improvements.

## [1.2.1] - 2021-07-22

- Update `parse-changelog` to 0.4.1. This includes a bug fix and performance improvements.

## [1.2.0] - 2021-07-20

- Add `branch` input option to reject releases from commits not contained in specified branches ([#7](https://github.com/taiki-e/create-gh-release-action/pull/7))

## [1.1.0] - 2021-06-23

- Add `draft` input option to create GitHub release as draft. ([#4](https://github.com/taiki-e/create-gh-release-action/pull/4), thanks @ririsoft)

## [1.0.3] - 2021-04-12

- Pin the version of `parse-changelog`.

## [1.0.2] - 2021-02-28

- Fix error on macOS and Windows. ([#2](https://github.com/taiki-e/create-gh-release-action/pull/2))

- Documentation improvements.

## [1.0.1] - 2021-02-12

- Pass `--noprofile` and `--norc` options to bash.

## [1.0.0] - 2021-02-03

Initial release

[Unreleased]: https://github.com/taiki-e/create-gh-release-action/compare/v1.6.3...HEAD
[1.6.3]: https://github.com/taiki-e/create-gh-release-action/compare/v1.6.2...v1.6.3
[1.6.2]: https://github.com/taiki-e/create-gh-release-action/compare/v1.6.1...v1.6.2
[1.6.1]: https://github.com/taiki-e/create-gh-release-action/compare/v1.6.0...v1.6.1
[1.6.0]: https://github.com/taiki-e/create-gh-release-action/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/taiki-e/create-gh-release-action/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/taiki-e/create-gh-release-action/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/taiki-e/create-gh-release-action/compare/v1.2.2...v1.3.0
[1.2.2]: https://github.com/taiki-e/create-gh-release-action/compare/v1.2.1...v1.2.2
[1.2.1]: https://github.com/taiki-e/create-gh-release-action/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/taiki-e/create-gh-release-action/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/taiki-e/create-gh-release-action/compare/v1.0.3...v1.1.0
[1.0.3]: https://github.com/taiki-e/create-gh-release-action/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/taiki-e/create-gh-release-action/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/taiki-e/create-gh-release-action/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/taiki-e/create-gh-release-action/releases/tag/v1.0.0
