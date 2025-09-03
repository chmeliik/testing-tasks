#!/bin/bash
set -o errexit -o nounset -o pipefail

# <TEMPLATED FILE!>
# This file comes from the templates at https://github.com/konflux-ci/task-repo-shared-ci.
# Please consider sending a PR upstream instead of editing the file directly.
# See the SHARED-CI.md document in this repo for more details.

shared_ci_files=$(
    grep -R '^# <TEMPLATED FILE!>' .github/ --files-with-matches |
    jq --raw-input | jq --slurp --compact-output
)

new_renovate_json=$(
    if [[ -s renovate.json ]]; then
        cat renovate.json
    else
        # renovate.json empty or missing => use default config
        # https://docs.renovatebot.com/config-overview/#onboarding-config
        jq -n '{
            "$schema": "https://docs.renovatebot.com/renovate-schema.json"
        }'
    fi | jq --argjson shared_ci_files "$shared_ci_files" '
        ((.ignorePaths + $shared_ci_files) | unique) as $new_ignore_paths |
        if .ignorePaths == $new_ignore_paths then
            empty
        else
            .ignorePaths = $new_ignore_paths
        end
    '
)

if [[ -z "$new_renovate_json" ]]; then
    echo "renovate.json is up to date" >&2
else
    if [[ -e renovate.json ]]; then
        echo "updated renovate.json" >&2
    else
        echo "created renovate.json" >&2
    fi
    printf '%s\n' "$new_renovate_json" > renovate.json
fi
