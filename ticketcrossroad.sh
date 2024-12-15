#!/bin/bash
#
# ticketcrossroad.sh
SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
source "$SCRIPT_DIR/ticketforgithub.sh"
source "$SCRIPT_DIR/ticketforgitea.sh"
source "$SCRIPT_DIR/ticketforjira.sh"

# This script checks the remote of a repo and either forwards to the script for github or gitea

ticketcrossroad() {
    remote=$(git remote -v | grep fetch | awk '{print $2}')

    if [[ $remote == *"github.com"* ]]; then
        # check if the repo has a github project

        # get the repo owner
        gh_name=$(git remote get-url origin | sed -e 's/.*github.com\///' -e 's/\/.*//')
        gh_name=${gh_name#*:}
        # get the repo name from path
        repo_name=$(basename $(git rev-parse --show-toplevel))

        repo_id="$(gh api graphql -f ownerrepo="$gh_name" -f reponame="$repo_name" -f query='
    query($ownerrepo: String!, $reponame: String!) {
        repository(owner: $ownerrepo, name: $reponame) {
            id
            projectsV2(first: 1, orderBy: {field: CREATED_AT, direction: DESC}) {
                nodes {
                    id
                    number
                }
            }
        }
    }')"
        repo_id=${repo_id#*\"id\":\"}
        # "projectsV2":{"nodes":[]} means no project
        no_project=$(echo "$repo_id" | grep -c "projectsV2\":{\"nodes\":\[\]}")
        if [[ $no_project -eq 0 ]]; then
            ticketforgithub "$@"
        else
            # assume it's jira
            ticketforjira "$@"
        fi
    else
        #assume gitea
        ticketforgitea "$@"
    fi
}
