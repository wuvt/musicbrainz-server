#!/bin/bash

pushd "$(dirname "${BASH_SOURCE[0]}")"

source config.default.sh

if [[ ! -z "$MBS_ADMIN_CONFIG" && -e "$MBS_ADMIN_CONFIG" ]]; then
    source "$MBS_ADMIN_CONFIG"
fi

popd
