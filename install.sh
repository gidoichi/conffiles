#!/bin/sh

set -eu

p() {
    printf '%s' "$*"
}

# EXAMPLE
# stdin json-array: [{"target":"in"},{"path":"p"}]
# $1 string: target
# $2 string: new
# output json-array: [{"target":"in"},{"path":"p","target":"new"}]
set_object_in_array_if_not_exists() (
    key="$1"
    val="$2"
    cat | jq -c '.[]' | while IFS= read -r sub; do
        p "${sub}" | jq --arg k "${key}" --arg v "${val}" 'if .[$k] then . else . += {($k):$v} end'
    done | jq -cs 'flatten(1)'
)

# EXAMPLE
# $1 json-object: {"target":"t1.txt", "path":"/path/to/p1", "when":"[ 1 -eq 1 ]"}
# stdout json-array: [{"target":"t1.txt", "path":"/path/to/p1"}]
collect() (
    json="$1"

    # base case at recursion
    arr='[{}]'

    if cond=$(p "${json}" | jq -ce '.cond'); then
        arr=$(
            p "${cond}" | jq -c '.[]' | while IFS= read -r sub; do
                collect "${sub}"
            done | jq -cs 'flatten(1)'
           )
    fi

    if when=$(p "${json}" | jq -er '.when'); then
        sh -uc "${when}" || return
    fi

    if target=$(p "${json}" | jq -er '.target'); then
        arr=$(p "${arr}" | set_object_in_array_if_not_exists 'target' "${target}")
    fi
    if path=$(p "${json}" | jq -er '.path'); then
        path=$(sh -euc "printf '%s' \"${path}\"")
        arr=$(p "${arr}" | set_object_in_array_if_not_exists 'path' "${path}")
    fi

    p "${arr}"
)

list() (
    conf="$1"

    p "${conf}" | jq -c '.place[]' | while IFS= read -r json; do
        collect "${json}"
    done

    # TODO: detect invalid config
)

PARENT="$(d=${0%/*}/; [ "_$d" = "_$0/" ] && d='./'; cd "$d"; pwd)"
conf="${PARENT}/installation-place.yml"

list=$(list "$(yq -o json "${conf}" | jq -c '.')")

p "${list}" | jq -c '.[]' | while IFS= read -r line; do
    path=$(p "${line}" | jq -r '.path')
    target=$(p "${line}" | jq -r '.target')
    # TODO: link file
    echo cp "${PARENT}/configs/${target}" "${path}${target}"
done
