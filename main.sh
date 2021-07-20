#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

parse_changelog_tag="v0.3.0"

error() {
    echo "::error::$*"
}

title="${INPUT_TITLE:?}"
changelog="${INPUT_CHANGELOG:-}"
draft="${INPUT_DRAFT:-}"
branch="${INPUT_BRANCH:-}"

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    error "GITHUB_TOKEN not set"
    exit 1
fi

if [[ "${GITHUB_REF:?}" != "refs/tags/"* ]]; then
    error "this action can only be used on 'push' event for 'tags' (GITHUB_REF should start with 'refs/tags/': '${GITHUB_REF}')"
    exit 1
fi
tag="${GITHUB_REF#refs/tags/}"

# TODO: Support custom prefix of tags https://github.com/taiki-e/create-gh-release-action/issues/1
if [[ ! "${tag}" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z_0-9\.-]+)?(\+[a-zA-Z_0-9\.-]+)?$ ]]; then
    error "invalid tag format: '${tag}'"
    exit 1
fi
if [[ "${tag}" =~ ^v?[0-9\.]+-[a-zA-Z_0-9\.-]+(\+[a-zA-Z_0-9\.-]+)?$ ]]; then
    prerelease="--prerelease"
fi
version="${tag#v}"
title="${title/\$tag/${tag}}"
title="${title/\$version/${version}}"

case "${draft}" in
    true)
        draft_option="--draft"
        ;;
    false) ;;
    *)
        error "'draft' input option must be 'true' or 'false': '${draft}'"
        exit 1
        ;;
esac

if [[ -n "${branch}" ]]; then
    git fetch &>/dev/null
    if ! git branch -r --contains | grep -E "(^|\s)origin/(${branch})$" &>/dev/null; then
        git branch -r --contains
        error "Creating of release is only allowed on commits contained in branches that match the specified pattern: '${branch}'"
        exit 1
    fi
fi

if [[ -n "${changelog}" ]]; then
    case "${OSTYPE}" in
        linux*)
            target="x86_64-unknown-linux-musl"
            ;;
        darwin*)
            target="x86_64-apple-darwin"
            ;;
        cygwin* | msys*)
            target="x86_64-pc-windows-msvc"
            ;;
        *)
            error "unrecognized OSTYPE: ${OSTYPE}"
            exit 1
            ;;
    esac
    # https://github.com/taiki-e/parse-changelog
    curl -LsSf "https://github.com/taiki-e/parse-changelog/releases/download/${parse_changelog_tag}/parse-changelog-${target}.tar.gz" \
        | tar xzf -
    notes=$(./parse-changelog "${changelog}" "${version}")
    rm -f ./parse-changelog
fi

# https://cli.github.com/manual/gh_release_view
if gh release view "${tag}" &>/dev/null; then
    # https://cli.github.com/manual/gh_release_delete
    gh release delete "${tag}" -y
fi

# https://cli.github.com/manual/gh_release_create
gh release create ${draft_option:-} "${tag}" ${prerelease:-} --title "${title}" --notes "${notes:-}"
