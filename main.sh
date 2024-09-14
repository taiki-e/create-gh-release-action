#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
set -eEuo pipefail
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
    echo "::error::$*"
    exit 1
}
warn() {
    echo "::warning::$*"
}
download_and_checksum() {
    local url="${1:?}"
    local checksum="${2:?}"
    retry curl --proto '=https' --tlsv1.2 -fsSL --retry 10 "${url}" -o tmp
    if type -P sha256sum &>/dev/null; then
        sha256sum -c - >/dev/null <<<"${checksum} *tmp"
    elif type -P shasum &>/dev/null; then
        # GitHub-hosted macOS runner does not install GNU Coreutils by default.
        # https://github.com/actions/runner-images/issues/90
        shasum -a 256 -c - >/dev/null <<<"${checksum} *tmp"
    else
        warn "checksum requires 'sha256sum' or 'shasum' command; consider installing one of them; skipped checksum for $(basename "${url}")"
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
token="${INPUT_TOKEN:-"${GITHUB_TOKEN:-}"}"
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
    prefix=$(grep <<<"${tag}" -Eo "^${prefix}")
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

if [[ -n "${changelog}" ]]; then
    # https://github.com/taiki-e/install-action/blob/HEAD/manifests/parse-changelog.json
    parse_changelog_version='0.6.9'
    exe=''
    case "$(uname -s)" in
        Linux)
            # AArch64 macOS/Windows can run x86_64 binaries, so handles architecture only on Linux.
            case "$(uname -m)" in
                aarch64 | arm64)
                    parse_changelog_target=aarch64-unknown-linux-musl
                    parse_changelog_checksum='4b34554144be39cb11a8b1aab0c05c4df7c4dc1bd8d79f263146b8159d0037dc'
                    ;;
                *)
                    parse_changelog_target=x86_64-unknown-linux-musl
                    parse_changelog_checksum='354c60eacad40b1eb4419108f2615eaa510d85b74c8c0cac66436fadd2d78f34'
                    ;;
            esac
            ;;
        Darwin)
            parse_changelog_target=x86_64-apple-darwin
            parse_changelog_checksum='a257c54537fefda492cafc55d164d432cf08c0d28ed8b3efe094cd909d488ed9'
            ;;
        MINGW* | MSYS* | CYGWIN* | Windows_NT)
            exe=.exe
            parse_changelog_target=x86_64-pc-windows-msvc
            parse_changelog_checksum='f4576c79cf86f9c2f7e5fcd9251e5924301337aadd07c49ab5f7273ff994ed99'
            ;;
        *) bail "unrecognized OS type '$(uname -s)'" ;;
    esac
    action_dir="${HOME}/.create-gh-release-action"
    mkdir -p "${action_dir}/bin"
    (
        cd "${action_dir}/bin"
        download_and_checksum "https://github.com/taiki-e/parse-changelog/releases/download/v${parse_changelog_version}/parse-changelog-${parse_changelog_target}.tar.gz" "${parse_changelog_checksum}"
        tar xzf tmp
    )
    parse_changelog_options+=("${changelog}" "${version}")

    # If allow_missing_changelog is true then default to empty value if version not found
    if [[ "${allow_missing_changelog}" == "true" ]]; then
        notes=$("${action_dir}/bin/parse-changelog${exe}" "${parse_changelog_options[@]}" || echo "")
    else
        notes=$("${action_dir}/bin/parse-changelog${exe}" "${parse_changelog_options[@]}")
    fi

    rm -rf "${action_dir}"
fi

# https://cli.github.com/manual/gh_release_view
if GITHUB_TOKEN="${token}" gh release view "${tag}" &>/dev/null; then
    # https://cli.github.com/manual/gh_release_delete
    GITHUB_TOKEN="${token}" gh release delete "${tag}" -y || true
fi

# https://cli.github.com/manual/gh_release_create
GITHUB_TOKEN="${token}" retry gh release create "${release_options[@]}" --title "${title}" --notes "${notes:-}"

# Set (computed) prefix and version outputs for future step use.
computed_prefix=${tag%"${version}"}
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "computed-prefix=${computed_prefix}" >>"${GITHUB_OUTPUT}"
    echo "version=${version}" >>"${GITHUB_OUTPUT}"
else
    # Self-hosted runner may not set GITHUB_OUTPUT.
    warn "GITHUB_OUTPUT is not set; skip setting 'computed-prefix' and 'version' outputs"
    echo "computed-prefix: ${computed_prefix}"
    echo "version: ${version}"
fi
