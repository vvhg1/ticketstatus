#!/bin/bash
#
# ticketcrossroad.sh
SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
source "$SCRIPT_DIR/../ghtik/ticketforgithub.sh"
source "$SCRIPT_DIR/ticketforgitea.sh"

# This script checks the remote of a repo and either forwards to the script for github or gitea

ticketcrossroad() {
remote=$(git remote -v | grep fetch | awk '{print $2}')

if [[ $remote == *"github.com"* ]]; then
    ticketforgithub "$@"
else
    #assume gitea
    ticketforgitea "$@"
fi
}


