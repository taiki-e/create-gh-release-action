#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
set -CeEuo pipefail
IFS=$'\n\t'

retry() {
  for i in {1..10}; do
    if "$@"; then
      return 0
    else
      sleep "${i}"
    fi
  done
  "$@"
}
bail() {
  printf '::error::%s\n' "$*"
  exit 1
}
warn() {
  printf '::warning::%s\n' "$*"
}
download_and_checksum() {
  local url="${1:?}"
  local checksum="${2:?}"
  retry curl --proto '=https' --tlsv1.2 -fsSL --retry 10 "${url}" -o tmp
  if type -P sha256sum >/dev/null; then
    sha256sum -c - >/dev/null <<<"${checksum} *tmp"
  elif type -P shasum >/dev/null; then
    # GitHub-hosted macOS runner does not install GNU Coreutils by default.
    # https://github.com/actions/runner-images/issues/90
    shasum -a 256 -c - >/dev/null <<<"${checksum} *tmp"
  else
    warn "checksum requires 'sha256sum' or 'shasum' command; consider installing one of them; skipped checksum for $(basename -- "${url}")"
  fi
}

if [[ $# -gt 0 ]]; then
  bail "invalid argument '$1'"
fi

# Input options
title="${INPUT_TITLE:?}"
changelog="${INPUT_CHANGELOG:-}"
allow_missing_changelog="${INPUT_ALLOW_MISSING_CHANGELOG:-}"
draft="${INPUT_DRAFT:-}"
branch="${INPUT_BRANCH:-}"
prefix="${INPUT_PREFIX:-}"
token="${INPUT_TOKEN:-"${GITHUB_TOKEN:-"${DEFAULT_GITHUB_TOKEN:-}"}"}"
# This prevents tokens from being exposed to subprocesses via environment variables.
# Note that this does not prevent token leaks via reading `/proc/*/environ` on Linux or
# via `ps -Eww` on macOS. It only reduces the risk of leaks.
unset INPUT_TOKEN GITHUB_TOKEN GH_TOKEN DEFAULT_GITHUB_TOKEN
ref="${INPUT_REF:-"${GITHUB_REF:-}"}"

if [[ -z "${token}" ]]; then
  bail "neither GITHUB_TOKEN environment variable nor 'token' input option is set"
fi

if [[ "${ref}" != "refs/tags/"* ]]; then
  bail "tag ref should start with 'refs/tags/': '${ref}'; this action only supports events from tag or release by default; see <https://github.com/taiki-e/create-gh-release-action#supported-events> for more"
fi
tag="${ref#refs/tags/}"

release_options=("${tag}")
parse_changelog_options=()
if [[ ! "${tag}" =~ ^${prefix}-?v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z\.-]+)?(\+[0-9A-Za-z\.-]+)?$ ]]; then
  # TODO: In the next major version, reject underscores in pre-release strings and build metadata.
  if [[ ! "${tag}" =~ ^${prefix}-?v?[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z_\.-]+)?(\+[0-9A-Za-z_\.-]+)?$ ]]; then
    bail "invalid tag format '${tag}'"
  fi
  warn "underscores are not allowed in semver's pre-release strings and build metadata; this will be rejected in the next major version of create-gh-release-action: '${tag}'"
  # parse-changelog 0.5+'s default version format strictly adheres to semver.
  parse_changelog_options+=(--version-format '^\d+\.\d+\.\d+(-[\w\.-]+)?(\+[\w\.-]+)?$')
fi
# TODO: In the next major version, reject underscores in pre-release strings and build metadata.
if [[ "${tag}" =~ ^${prefix}-?v?[0-9\.]+-[0-9A-Za-z_\.-]+(\+[0-9A-Za-z_\.-]+)?$ ]]; then
  release_options+=("--prerelease")
fi

version="${tag}"
# extract the portion of the tag matching the prefix pattern
if [[ -n "${prefix}" ]]; then
  prefix=$(grep -Eo "^${prefix}" <<<"${tag}")
  prefix="${prefix%-}"
  version="${tag#"${prefix}"}"
  version="${version#-}"
fi
version="${version#v}"

# interpolate $tag, $version, and $prefix into the title string
title="${title/\$tag/${tag}}"
title="${title/\$version/${version}}"
title="${title/\$prefix/${prefix}}"
# interpolate $tag, $version, and $prefix into the changelog path
changelog="${changelog/\$tag/${tag}}"
changelog="${changelog/\$version/${version}}"
changelog="${changelog/\$prefix/${prefix}}"
case "${draft}" in
  true) release_options+=("--draft") ;;
  false) ;;
  *) bail "'draft' input option must be 'true' or 'false': '${draft}'" ;;
esac
case "${allow_missing_changelog}" in
  true | false) ;;
  *) bail "'allow_missing_changelog' input option must be 'true' or 'false': '${allow_missing_changelog}'" ;;
esac

if [[ -n "${branch}" ]]; then
  git fetch &>/dev/null
  if ! git branch -r --contains | grep -Eq "(^|\s)origin/(${branch})$"; then
    git branch -r --contains
    bail "creating of release is only allowed on commits contained in branches that match the specified pattern '${branch}'"
  fi
fi

notes=''
if [[ -n "${changelog}" ]]; then
  # https://github.com/taiki-e/install-action/blob/HEAD/manifests/parse-changelog.json
  parse_changelog_version='0.6.18'
  exe=''
  case "$(uname -m)" in
    aarch64 | arm64) host_arch=aarch64 ;;
    ppc64le) host_arch=powerpc64le ;;
    riscv64) host_arch=riscv64 ;;
    s390x) host_arch=s390x ;;
    *) host_arch=x86_64 ;;
  esac
  case "$(uname -s)" in
    Linux)
      parse_changelog_target=${host_arch}-unknown-linux-musl
      case "${host_arch}" in
        x86_64) parse_changelog_hash='e0f0aa87a94501111052dbb7f3c79b28b61ab421427641ba9ac4e4ae61d6eee9' ;;
        aarch64) parse_changelog_hash='ca1e216f84999487a73edff60f4df735584d5b5cae31617ac81450c4b6f2879a' ;;
        powerpc64le) parse_changelog_hash='bce814051189225b1f3410b3cf75bdf98fd482f831d401b7edb86dbfbb7b28dd' ;;
        riscv64)
          parse_changelog_target=${host_arch}gc-unknown-linux-musl
          parse_changelog_hash='b4dec46f5ed9afc0e66357d669bbfc17a85ac1456047234f20667bcef4687c44'
          ;;
        s390x)
          parse_changelog_target=${host_arch}-unknown-linux-gnu
          parse_changelog_hash='70e2cf19bb3491a177fe900aca7f7de0e7bbe809162e6430c1165c6413a060bc'
          ;;
        *) bail "unrecognized host '${parse_changelog_target}'" ;;
      esac
      ;;
    Darwin)
      parse_changelog_target=${host_arch}-apple-darwin
      case "${host_arch}" in
        x86_64) parse_changelog_hash='af5b9bf13e26ab93492592fb3d86d591398a7ac921f54f3d0086dae109639d70' ;;
        aarch64) parse_changelog_hash='56158c595174012c2116562de282bdbc35b4388856007db2aa991cb3a35debb4' ;;
        *) bail "unrecognized host '${parse_changelog_target}'" ;;
      esac
      ;;
    MINGW* | MSYS* | CYGWIN* | Windows_NT)
      exe=.exe
      parse_changelog_target=${host_arch}-pc-windows-msvc
      case "${host_arch}" in
        x86_64) parse_changelog_hash='f01ef8cd853f27541ca0de36efb45fd61515fdefa61eca789cea1f3684ef4250' ;;
        aarch64) parse_changelog_hash='fbe3be7fe3b6c66e7dbfb687633bfa9bd31b71d1feedced6b5d9080c56773895' ;;
        *) bail "unrecognized host '${parse_changelog_target}'" ;;
      esac
      ;;
    *) bail "unrecognized OS type '$(uname -s)'" ;;
  esac
  action_dir="${HOME}/.create-gh-release-action"
  mkdir -p -- "${action_dir}/bin"
  (
    cd -- "${action_dir}/bin"
    download_and_checksum "https://github.com/taiki-e/parse-changelog/releases/download/v${parse_changelog_version}/parse-changelog-${parse_changelog_target}.tar.gz" "${parse_changelog_hash}"
    tar xzf tmp
  )
  parse_changelog_options+=("${changelog}" "${version}")

  # If allow_missing_changelog is true then default to empty value if version not found
  if [[ "${allow_missing_changelog}" == "true" ]]; then
    notes=$("${action_dir}/bin/parse-changelog${exe}" "${parse_changelog_options[@]}" || true)
  else
    notes=$("${action_dir}/bin/parse-changelog${exe}" "${parse_changelog_options[@]}")
  fi

  rm -rf -- "${action_dir}"
fi

# https://cli.github.com/manual/gh_release_view
if GITHUB_TOKEN="${token}" gh release view "${tag}" &>/dev/null; then
  # https://cli.github.com/manual/gh_release_delete
  GITHUB_TOKEN="${token}" gh release delete "${tag}" -y || true
fi

# https://cli.github.com/manual/gh_release_create
GITHUB_TOKEN="${token}" retry gh release create "${release_options[@]}" --title "${title}" --notes "${notes}"

# Set (computed) prefix and version outputs for future step use.
computed_prefix=${tag%"${version}"}
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  printf 'computed-prefix=%s\n' "${computed_prefix}" >>"${GITHUB_OUTPUT}"
  printf 'version=%s\n' "${version}" >>"${GITHUB_OUTPUT}"
else
  # Self-hosted runner may not set GITHUB_OUTPUT.
  warn "GITHUB_OUTPUT is not set; skip setting 'computed-prefix' and 'version' outputs"
  printf 'computed-prefix: %s\n' "${computed_prefix}"
  printf 'version: %s\n' "${version}"
fi
