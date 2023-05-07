#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# https://github.com/taiki-e/parse-changelog/releases
parse_changelog_version="0.5.2"

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

if [[ $# -gt 0 ]]; then
    bail "invalid argument '$1'"
fi

# Input options
title="${INPUT_TITLE:?}"
changelog="${INPUT_CHANGELOG:-}"
allow_missing_changelog="${INPUT_ALLOW_MISSING_CHANGELOG:-}"
draft="${INPUT_DRAFT:-}"
latest="${INPUT_LATEST:-}"
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
if [[ ! "${prefix}" = "" ]]; then
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
case "${latest}" in
    true) edit_options+=("--latest") ;;
    false) edit_options+=("--latest=false") ;;
    '') ;; # default
    *) bail "'latest' input option must be 'true' or 'false': '${latest}'" ;;
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
    tar="tar"
    case "${OSTYPE}" in
        linux*) parse_changelog_target="x86_64-unknown-linux-musl" ;;
        darwin*)
            parse_changelog_target="x86_64-apple-darwin"
            tar="gtar"
            if ! type -P gtar &>/dev/null; then
                brew install gnu-tar &>/dev/null
            fi
            ;;
        cygwin* | msys*) parse_changelog_target="x86_64-pc-windows-msvc" ;;
        *) bail "unrecognized OSTYPE '${OSTYPE}'" ;;
    esac
    # https://github.com/taiki-e/parse-changelog
    retry curl --proto '=https' --tlsv1.2 -fsSL --retry 10 --retry-connrefused "https://github.com/taiki-e/parse-changelog/releases/download/v${parse_changelog_version}/parse-changelog-${parse_changelog_target}.tar.gz" \
        | "${tar}" xzf -
    parse_changelog_options+=("${changelog}" "${version}")

    # If allow_missing_changelog is true then default to empty value if version not found
    if [[ "${allow_missing_changelog}" == "true" ]]; then
        notes=$(./parse-changelog "${parse_changelog_options[@]}" || echo "")
    else
        notes=$(./parse-changelog "${parse_changelog_options[@]}")
    fi

    rm -f ./parse-changelog
fi

# https://cli.github.com/manual/gh_release_view
if GITHUB_TOKEN="${token}" gh release view "${tag}" &>/dev/null; then
    # https://cli.github.com/manual/gh_release_delete
    GITHUB_TOKEN="${token}" gh release delete "${tag}" -y
fi

# https://cli.github.com/manual/gh_release_create
GITHUB_TOKEN="${token}" gh release create "${release_options[@]}" --title "${title}" --notes "${notes:-}"

# TODO: check edit_options is not empty
# TODO: not work
# https://cli.github.com/manual/gh_release_edit
GITHUB_TOKEN="${token}" gh release edit "${edit_options[@]}" "${tag}"

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
