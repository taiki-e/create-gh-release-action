#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

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

title="${INPUT_TITLE:?}"
changelog="${INPUT_CHANGELOG:-}"
draft="${INPUT_DRAFT:-}"
branch="${INPUT_BRANCH:-}"
prefix="${INPUT_PREFIX:-}"
github_ref="${INPUT_GITHUBREF:-}"

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    bail "GITHUB_TOKEN not set"
fi

if [[ "${github_ref:?}" != "refs/tags/"* ]]; then
    bail "this action can only be used on 'push' event for 'tags' (github_ref should start with 'refs/tags/': '${github_ref}')"
fi
tag="${github_ref#refs/tags/}"

if [[ ! "${tag}" =~ ^${prefix}-?v?[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z\.-]+)?(\+[0-9A-Za-z\.-]+)?$ ]]; then
    # TODO: In the next major version, reject underscores in pre-release strings and build metadata.
    if [[ ! "${tag}" =~ ^${prefix}-?v?[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z_\.-]+)?(\+[0-9A-Za-z_\.-]+)?$ ]]; then
        bail "invalid tag format '${tag}'"
    fi
    warn "underscores are not allowed in semver's pre-release strings and build metadata: '${tag}'"
fi
# TODO: In the next major version, reject underscores in pre-release strings and build metadata.
if [[ "${tag}" =~ ^${prefix}-?v?[0-9\.]+-[0-9A-Za-z_\.-]+(\+[0-9A-Za-z_\.-]+)?$ ]]; then
    prerelease="--prerelease"
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
    true) draft_option="--draft" ;;
    false) ;;
    *) bail "'draft' input option must be 'true' or 'false': '${draft}'" ;;
esac

if [[ -n "${branch}" ]]; then
    git fetch &>/dev/null
    if ! git branch -r --contains | grep -Eq "(^|\s)origin/(${branch})$"; then
        git branch -r --contains
        bail "creating of release is only allowed on commits contained in branches that match the specified pattern '${branch}'"
    fi
fi

if [[ -n "${changelog}" ]]; then
    regex='^[#]{1,2}\s'
    firstmatch=
    secondmatch=
    thirdmatch=

    while read line; do
        if [[ $line =~ $regex && -z "$firstmatch" ]]; then
            firstmatch=$line
        elif [[ $line =~ $regex && -z "$secondmatch" ]]; then
            secondmatch=$line
        elif [[ $line =~ $regex && -z "$thirdmatch" ]]; then
            thirdmatch=$line
        elif [[ -n "$secondmatch" && -z "$thirdmatch" ]]; then
            echo $line >> CHANGELOG_SMALL.md
        fi
    done < $changelog
fi

# https://cli.github.com/manual/gh_release_view
if gh release view "${tag}" &>/dev/null; then
    # https://cli.github.com/manual/gh_release_delete
    gh release delete "${tag}" -y
fi

# https://cli.github.com/manual/gh_release_create
gh release create ${draft_option:-} "${tag}" ${prerelease:-} --title "${title}" -F CHANGELOG_SMALL.md

# set (computed) prefix and version outputs for future step use
computed_prefix=${tag%"${version}"}
echo "::set-output name=computed-prefix::${computed_prefix}"
echo "::set-output name=version::${version}"

rm -rf CHANGELOG_SMALL.md