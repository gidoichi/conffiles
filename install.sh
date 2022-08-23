#!/bin/sh

set -eu

# EXAMPLE
# $1(json-object): {"target":"t1.txt", "path":"/path/to/p1", "when":"[ 1 -eq 1 ]"}
# stdout(json-array): [{"target":"t1.txt", "path":"/path/to/p1"}]
collect() (
    json="$1"

    # base case at recursion
    arr='[{}]'

    if cond=$(printf '%s' "${json}" | jq -ce '.cond'); then
        arr=$(
            printf '%s' "${cond}" | jq -c '.[]' | while IFS= read -r sub; do
                collect "${sub}"
            done | jq -cs 'flatten(1)'
           )
    fi

    if when=$(printf '%s' "${json}" | jq -er '.when'); then
        sh -uc "${when}" || return
    fi

    if target=$(printf '%s' "${json}" | jq -er '.target'); then
        arr=$(
            printf '%s' "${arr}" | jq -c '.[]' | while IFS= read -r sub; do
                printf '%s' "${sub}" | jq --arg target "${target}" 'if .target then . else . += {"target":$target} end'
            done | jq -cs 'flatten(1)'
           )
    fi

    if path=$(printf '%s' "${json}" | jq -er '.path'); then
        path=$(sh -euc "printf '%s' \"${path}\"")
        arr=$(
            printf '%s' "${arr}" | jq -c '.[]' | while IFS= read -r sub; do
                printf '%s' "${sub}" | jq --arg path "${path}" 'if .path then . else . += {"path":$path} end'
            done | jq -cs 'flatten(1)'
           )
    fi

    printf '%s' "${arr}"
)

list() (
    conf="$1"

    printf '%s' "${conf}" | jq -c '.place[]' | while IFS= read -r json; do
        collect "${json}"
    done

    # TODO: detect invalid config
)

PARENT="$(d=${0%/*}/; [ "_$d" = "_$0/" ] && d='./'; cd "$d"; pwd)"
conf="${PARENT}/installation-place.yml"

list=$(list "$(yq -o json "${conf}" | jq -c '.')")

printf '%s' "${list}" | jq -c '.[]' | while IFS= read -r line; do
    path=$(printf '%s' "${line}" | jq -r '.path')
    target=$(printf '%s' "${line}" | jq -r '.target')
    # TODO: link file
    echo cp "${PARENT}/configs/${target}" "${path}${target}"
done
