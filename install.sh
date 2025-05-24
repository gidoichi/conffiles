#!/bin/sh

set -eu

p() {
    printf '%s' "$*"
}

debug() {
    (set -x; : "$@")
    "$@"
}

ln_if_not_create() {
    src="$1"
    dst="$2"
    if [ -L "${dst}" ]; then
        inode_src="$(ls -di "${src}" | cut -d ' ' -f 1)"
        inode_dst="$(ls -di "$(readlink "${dst}")" 2>/dev/null | cut -d ' ' -f 1)"
        if [ "${inode_src}" -eq "${inode_dst}" ] 2>/dev/null; then
            return
        fi
    fi

    mkdir "${dst%/*}"
    if [ -n "$command" ]; then
        target="$src"
        path="$dst"
        eval "debug $command" </dev/tty
    else
        debug ln -is "${src}" "${dst}" </dev/tty
    fi
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
        sh -uc "${when}" >/dev/null 2>&1 || return
    fi

    if command=$(p "${json}" | jq -er '.command'); then
        arr=$(p "${arr}" | set_object_in_array_if_not_exists 'command' "${command}")
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

jq --help >/dev/null
yq --help >/dev/null

PARENT="$(d=${0%/*}/; [ "_$d" = "_$0/" ] && d='./'; cd "$d"; pwd)"
conf="${PARENT}/installation-place.yml"

list=$(list "$(yq -o json "${conf}" | jq -c '.')")

p "${list}" | jq -c '.[]' | while IFS= read -r line; do
    path=$(p "${line}" | jq -r '.path')
    target=$(p "${line}" | jq -r '.target')
    command=$(p "${line}" | jq -r '.command // empty')
    ln_if_not_create "${PARENT}/configs/${target}" "${path}"
done
