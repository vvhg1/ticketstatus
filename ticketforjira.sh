#!/bin/bash

# This script is used to manage jira tickets in a project
# prerequisites:
# the rep name must start with the project prefix
# labels for branch types are:
# hotfix, bugfix, test, feature
ticketforjira() {
    check_yes_no_internal() {
        while true; do
            sleep 0.1
            # check which shell is being used
            if [ -n "$BASH_VERSION" ]; then
                read -p "$1" yn
            elif [ -n "$ZSH_VERSION" ]; then
                vared -p "$1" -c yn
            fi
            # read -p "$1" yn
            if [ "$yn" = "" ]; then
                yn='Y'
            fi
            case "$yn" in
                [Yy]) return 0 ;;
                [Nn]) return 1 ;;
                *) echo -n "Not a valid option. Please enter y or n: " ;;
            esac
        done
    }
    show_help() {
        echo "ticketforjira"
        echo "Checks and changes the status of tickets on jira"
        echo "The tickets will be checked in the current directory's git repo"
        echo ""
        echo "Usage: ticketforjira [flags]"
        echo ""
        echo "Flags"
        echo ""
        echo "-h, --help: Show help"
        echo ""
        echo "-a, --all: Show all tickets, otherwise don't show done tickets"
        echo ""
        echo "-l, --list: List all tickets in the current project"
        echo ""
        echo "-o, --options: Show all status options"
        echo ""
        echo "-c, --current: Show all tickets in the current sprint only"
        echo ""
        echo "Tickets can be searched by fuzzy searching"
        echo "Selecting a ticket will move on to the next step where you can manipulate the ticket"
        echo "The ticket can be moved to a different status column, or closed"
        echo "The ticket can be assigned to a user, @me will assign it to you"
        return 0
    }
    print_issue() {

        # print step by step
        full_issue_key=$(echo "$full_issue" | jq -r '.key')
        full_issue_summary=$(echo "$full_issue" | jq -r '.fields.summary')
        full_issue_story_points=$(echo "$full_issue" | jq -r '
  if .fields.customfield_10016 != null then
    (.fields.customfield_10016 | floor)
  else
    "-"
  end
')
        full_issue_status=$(echo "$full_issue" | jq -r '.fields.status.name')
        full_issue_assignee=$(echo "$full_issue" | jq -r '.fields.assignee.displayName // "-"')
        full_issue_created=$(echo "$full_issue" | jq -r '.fields.created')
        full_issue_issuetype=$(echo "$full_issue" | jq -r '.fields.issuetype.name')
        # we need to get the labels into one line
        full_issue_labels=$(echo "$full_issue" | jq -r '.fields.labels[]' | tr '\n' ' ')
        full_issue_parent=$(echo "$full_issue" | jq -r 'if .fields.parent == null then
    "-"
else "\(.fields.parent.key)\t\(.fields.parent.fields.summary)\t\(
  if .fields.parent.customfield_10016 != null then
    (.fields.parent.customfield_10016 | floor)
  else
    "-"
  end
)\t\(.fields.parent.fields.status.name)" end')
        full_issue_description=$(echo "$full_issue" | jq -r '.fields.description')
        full_issue_children=$(echo "$full_issue" | jq -r '.fields.subtasks[] | "\(.key)\t\(.fields.summary)\t\(.fields.status.name)"')

        # Process the JSON with jq
        if [ "$full_issue_description" == "null" ]; then
            formatted_text="No description available"
        else
            formatted_text=$(echo "$full_issue_description" | jq -r '
            def process_node(content; indent):
                if .type == "paragraph" then
                    .content[] |
                        if .type == "text" then
                            .text
                        elif .type == "inlineCard" then
                            "[URL: \(.attrs.url)]"
                        elif .type == "hardBreak" then
                            "\n"
                        elif .type == "inlineCard" then
                            "[URL: \(.attrs.url)]"
                        else
                            ""
                        end
                elif .type == "heading" then
                    ("#" * (.attrs.level)) + " " + (.content[0].text)
                elif .type == "orderedList" then
                    (.attrs.order // indent) as $indent |
                    .content[] | 
                    ("    " * ($indent)) + "* "+ process_node(.content; 0)
                elif .type == "listItem" then
                    .content[] |
                    process_node(.content; 0)
                else
                        ""
                end;
            .content[] |
            process_node(.content; 0)
       ')
        fi
        # Output the formatted text
        printf "\033[1;31m$full_issue_key\033[0m - $full_issue_summary\n"
        printf "\33[1mStorypoints: $full_issue_story_points\n\33[0m"
        printf "\33[1m\nStatus: $full_issue_status\n\n\33[0m"
        printf '%s\n' "Created: $full_issue_created"
        printf '%s\n' "Assignee: $full_issue_assignee"
        printf '%s\n' "Issue Type: $full_issue_issuetype"
        printf '%s\n' "Labels: $full_issue_labels"
        printf '%s\n' "Parent: $full_issue_parent"
        if [ "$full_issue_children" == "" ]; then
            printf "Children: -"
        else
            printf "Children:\n$full_issue_children"
        fi
        printf "\n\033[1;31m\nDescription:\033[0m\n"
        printf "$formatted_text\n\n"
        printf '%s\n' "-------------------------"
    }
    show_all=false
    only_list=false
    for arg in "$@"; do
        case $arg in
            -h | --help)
                show_help
                return 0
                ;;
            -a | --all)
                show_all=true
                ;;
            -l | --list)
                only_list=true
                ;;
            -c | --current)
                only_current=true
                ;;
            -o | --options)
                all_options=true
                ;;
            -ac | -ca)
                show_all=true
                only_current=true
                ;;
            -la | -al)
                show_all=true
                only_list=true
                ;;
            -lc | -cl)
                only_current=true
                only_list=true
                ;;
            -co | -oc)
                only_current=true
                all_options=true
                ;;
            -lac | -cla | -lca | -cal | -acl | -alc)
                show_all=true
                only_current=true
                only_list=true
                ;;
            -lo | -ol)
                only_list=true
                all_options=true
                ;;
            -lco | -loc | -clo | -col | -ocl | -olc)
                only_current=true
                only_list=true
                all_options=true
                ;;
            -ao | -oa)
                show_all=true
                all_options=true
                ;;
            -aoc | -aco | -oac | -oca | -cao | -coa)
                show_all=true
                only_current=true
                all_options=true
                ;;
            -lao | -loa | -alo | -aol | -ola | -oal)
                show_all=true
                only_list=true
                all_options=true
                ;;
            -laco | -laoc | -loac | -loca | -lcao | -lcoa | -alco | -aloc | -aclo | -acol | -aocl | -aolc | -olac | -olca | -oalc | -oacl | -ocal | -ocla)
                show_all=true
                only_current=true
                only_list=true
                all_options=true
                ;;
            *)
                echo "Invalid flag $arg"
                return 1
                ;;
        esac
    done

    # NOTE: use the email switching script if it exists so that the email is set before we call this
    if [ -n "$(command -v setdynamicgitemail)" ]; then
        setdynamicgitemail

    fi
    jira_email=$(git config user.email)
    # api token
    if [ -z "$jira_email" ]; then
        echo "git email not set, please set it with: git config --global user.email 'your@email.com'"
        return 1
    fi
    # api token
    jira_api_token=$JIRA_API_TOKEN
    if [ "$jira_api_token" == "" ]; then
        if command -v pass &>/dev/null; then
            jira_api_token=$(pass jiraapi)
            # try to read token from env
        else
            echo "neither pass nor JIRA_API_TOKEN is set, please set the jira_api_token environment variable or install pass and add the jiraapi password"
            return 1
        fi
    fi
    # get the repo owner
    gh_name=$(git remote get-url origin | sed -e 's/.*github.com\///' -e 's/\/.*//')
    gh_name=${gh_name#*:}
    # to lower case
    gh_name=${gh_name,,}
    # get the name up to the first dash
    repo_owner=${gh_name%%-*}
    repo_owner=${repo_owner,,}
    # get the repo name from path
    repo_name=$(basename $(git rev-parse --show-toplevel))
    # WARN: this is a hack, we should get the prefix from the issue? Maybe the labels?
    # repo name should start with AI but doesn't, lets pretend it does
    # repo_name="AI-$repo_name"
    project_name=${repo_name%%-*}
    project_name=${project_name,,}

    projects_url="https://${repo_owner}.atlassian.net/rest/api/3/project/search"
    # Fetch project overview
    response=$(curl -s -X GET \
        -H "Authorization: Basic $(echo -n "$jira_email:$jira_api_token" | base64)" \
        -H "Accept: application/json" \
        "$projects_url")

    # echo "response: $response"
    # Check if the response is valid
    if [[ -z "$response" ]]; then
        echo "Failed to fetch project data."
        return 1
    fi

    keys=$(echo "$response" | jq -r '.values[] | .key')

    if [[ -z "$keys" ]]; then
        echo "No projects found"
        return 1
    fi
    # search for the project in the keys, keys are one per line, we need to subtract 1 from the line number
    line_number=$(echo "$keys" | grep -i -n "$project_name" | cut -d ":" -f 1)
    # Subtract 1 from the line number
    if [[ -n "$line_number" ]]; then
        matched_project_index=$((line_number - 1))
    fi
    matched_project=$(echo "$keys" | grep -i "$project_name")
    if [ -z "$matched_project" ]; then
        echo "Project '$project_name' not found"
        return 1
    fi

    # get the project id
    project_id=$(echo "$response" | jq -r '.values['$matched_project_index'] | .id')

    boards_url="https://${repo_owner}.atlassian.net/rest/agile/1.0/board"
    bresponse=$(curl -s -X GET \
        -H "Authorization: Basic $(echo -n "$jira_email:$jira_api_token" | base64)" \
        -H "Accept: application/json" \
        "$boards_url")

    # Check if the response is valid
    if [[ -z "$bresponse" ]]; then
        echo "Failed to fetch board."
        return 1
    fi

    board_id=$(echo "$bresponse" | jq -r '.values[] | select(.location.projectId == '$project_id') | .id')

    # get the people on the project
    people_url="https://${repo_owner}.atlassian.net/rest/api/3/user/assignable/search?project=$project_id&startAt=0&maxResults=50"
    people_response=$(curl -s -X GET \
        -H "Authorization: Basic $(echo -n "$jira_email:$jira_api_token" | base64)" \
        -H "Accept: application/json" \
        "$people_url")

    # Check if the response is valid
    if [[ -z "$people_response" ]]; then
        echo "Failed to fetch people."
        return 1
    fi

    people_names=$(echo "$people_response" | jq -r '.[].displayName')
    people_ids=$(echo "$people_response" | jq -r '.[] | .accountId')

    # get the issues
    issues_url="https://${repo_owner}.atlassian.net/rest/agile/1.0/board/$board_id/issue"
    # WARN: hardcoded maxResults
    maxResults=800
    fields="id,key,summary,status,assignee,created,issuetype,labels,parent,sprint,customfield_10016"
    # only not closed or done if not show_all
    if [ "$show_all" = false ]; then
        jql="status%20not%20in%20(Done%2C%20Closed)"
    else
        jql=""
    fi
    issues_response=$(curl -s -X GET \
        -H "Authorization: Basic $(echo -n "$jira_email:$jira_api_token" | base64)" \
        -H "Accept: application/json" \
        "$issues_url?startAt=0&maxResults=$maxResults&fields=$fields&jql=$jql")

    # Check if the response is valid
    if [[ -z "$issues_response" ]]; then
        echo "Failed to fetch issues."
        return 1
    fi

    # window width
    window_size=$(tput cols)

    # max summary length
    max_summary_length=$((window_size - 110))
    if [ "$max_summary_length" -lt 60 ]; then
        max_summary_length=60
    fi
    # now we need to get the fields we want
    if [ "$only_current" = true ]; then
        # clean issues filtered for current sprint
        clean_issues=$(echo "$issues_response" | jq -r '.issues[] | select(.fields.sprint != null) | "\(.id)\t\(.key)\t\((.fields.summary))\t\(
      if .fields.customfield_10016 != null then
        (.fields.customfield_10016 | floor)
      else
        "null"
      end
    )\t\(.fields.status.name)\t\(.fields.assignee.displayName)\t\(.fields.created)\t\(.fields.issuetype.name)\t\(.fields.labels)\t\(.fields.parent.key)"')
    else
        clean_issues=$(echo "$issues_response" | jq -r '.issues[] | "\(.id)\t\(.key)\t\(.fields.summary)\t\(
      if .fields.customfield_10016 != null then
        (.fields.customfield_10016 | floor)
      else
        "null"
      end
    )\t\(.fields.status.name)\t\(.fields.assignee.displayName)\t\(.fields.created)\t\(.fields.issuetype.name)\t\(.fields.labels)\t\(.fields.parent.key)"')
    fi
    # clean up the missing fields
    clean_issues=$(echo "$clean_issues" | sed 's`\[\]`-`g' | sed 's`null`-`g' | sed 's`\[``g' | sed 's`\]``g')
    # format the date
    clean_issues=$(echo "$clean_issues" | sed -E 's`(.*)[0-9]{2}([0-9]{2}-[0-9]{2}-[0-9]{2})T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}[\+-]{1}[0-9]{4}(.*)`\1\2\3`')
    header="Id"$'\t'"Key"$'\t'"Summary"$'\t'"SP"$'\t'"Status"$'\t'"Assignee"$'\t'"Created"$'\t'"Issue Type"$'\t'"Labels"$'\t'"Parent"
    # add the header
    clean_issues="$header
    $clean_issues"
    formatted_issues=$(echo "$clean_issues" | awk -F '\t' -v maxlen="$max_summary_length" '
{
    summary = $3
    if (length(summary) > maxlen) {
        short_summary = substr(summary, 1, maxlen) "..."
        # Reconstruct the line with the truncated summary
        printf "%s\t%s\t%s", $1, $2, short_summary
        for (i = 4; i <= NF; i++) printf "\t%s", $i
        printf "\n"
    } else {
        # Print the line as is
        print
    }
}')

    # sort and column
    input_header=$(printf '%s\n' "${formatted_issues[@]}" | column -s$'\t' -t | head -n 1 | sed -E 's/^[^[:space:]]+[[:space:]]+//')

    # if only listing, print and exit
    if [ "$only_list" = true ]; then
        if [ "$show_all" = true ]; then
            printf '%s\n' "${formatted_issues[@]}" | awk -F '\t' '{print $2"\t"$3"\t"$4"\t"$5"\t"$6"\t"$7"\t"$8}' | sort -t '\t' -k 2 -r | column -s$'\t' -t
        else
            printf '%s\n' "${formatted_issues[@]}" | awk -F '\t' '{print $2"\t"$3"\t"$4"\t"$5"\t"$6"\t"$7"\t"$8}' | sort -t '\t' -k 2 -r | awk -F '\t' '$4 != "Done" && $4 != "done"' | column -s$'\t' -t
        fi
        return 0
    fi
    if [ "$show_all" = true ]; then
        # show the 5th column (status)
        issuei="$(printf '%s\n' "$formatted_issues" | tail -n +2 | sort -t '\t' -k 3 -r | column -s$'\t' -t | fzf --header="$input_header" --with-nth=2..)"
    else
        # TODO: make this more robust
        issuei="$(printf '%s\n' "${formatted_issues[@]}" | tail -n +2 | sort -t '\t' -k 2 -r | awk -F '\t' '$5 != "Done" && $5 != "done" && $5 != "Closed" && $5 != "closed"' | column -s$'\t' -t | fzf --header="$input_header" --with-nth=2..)"
    fi
    if [ -z "$issuei" ]; then
        echo "No issue selected"
        return 0
    fi
    issue_num=$(echo "$issuei" | awk '{$1=$1};1' | awk '{print $1}')

    # print the issue, first we get the full issue
    issues_url="https://${repo_owner}.atlassian.net/rest/api/3/issue/$issue_num"
    full_issue=$(curl -s -X GET \
        -H "Authorization: Basic $(echo -n "$jira_email:$jira_api_token" | base64)" \
        -H "Accept: application/json" \
        "$issues_url")

    # Check if the response is valid
    if [[ -z "$full_issue" ]]; then
        echo "Failed to fetch issue."
        return 1
    fi

    print_issue "$full_issue"
    # status options:
    # actions should be the possible transitions
    transitions_url="https://${repo_owner}.atlassian.net/rest/api/3/issue/$issue_num/transitions"
    response=$(curl -s -X GET \
        -H "Authorization: Basic $(echo -n "$jira_email:$jira_api_token" | base64)" \
        -H "Accept: application/json" \
        "$transitions_url")

    # Check if the response is valid
    if [[ -z "$response" ]]; then
        echo "Failed to fetch transitions."
        return 1
    fi

    # echo "response: $response"
    # get the transitions
    transitions=$(echo "$response" | jq -r '.transitions[] | "\(.id)    \(.to.statusCategory.id)    \(.name)"')
    # actions=$transitions
    # Append additional options to the actions list
    # substitute Closed/closed/CLOSED with Close issue
    transitions=$(echo "$transitions" | sed 's/Closed/Close issue/g' | sed 's/closed/Close issue/g' | sed 's/CLOSED/Close issue/g')
    transitions+="
null    null    Jump to branch
null    null    Assign"
    actions=$transitions
    full_issue_children=$(echo "$full_issue" | jq -r '.fields.subtasks[]')
    full_issue_parent=$(echo "$full_issue" | jq -r '.fields.parent')
    full_issue_key=$(echo "$full_issue" | jq -r '.key')
    if [ "$full_issue_children" != "" ]; then
        actions+="
null    null    Show children"
    fi
    if [ "$full_issue_parent" != "null" ]; then
        actions+="
null    null    Show parent"
    fi
    # Close and the columns
    # two possibilities:
    # 1. show all options
    # 2. show only in progress and sprint backlog and pr
    if [ "$all_options" = false ]; then
        echo "not all_options"
        # TODO: implement this, not sure this is needed, might be handled by the available transitions from jira side
    fi
    # remove the current status from the actions
    actions=$(echo "$actions" | grep -vi "$full_issue_status")
    # let the user choose the status
    #
    status=$(printf '%s\n' "${actions[@]}" | fzf --with-nth=3..)
    status_id=$(echo "$status" | awk '{print $1}')
    status_name=$(echo "$status" | awk -F '    ' '{print $3}')

    if [ "$status_name" == "Show children" ]; then
        # we filter the tickets for parent == full_issue_key, no need to curl as we already have the issues
        if [ "$only_current" = true ]; then
            # clean issues filtered for current sprint
            issue_subtasks=$(echo "$issues_response" | jq -r '.issues[] | select(.fields.sprint != null) | select(.fields.parent.key == "'$full_issue_key'") | "\(.id)\t\(.key)\t\(.fields.summary)\t\(.fields.status.name)\t\(.fields.assignee.displayName)\t\(.fields.created)\t\(.fields.issuetype.name)\t\(.fields.labels)\t\(.fields.parent.key)"')
        else
            issue_subtasks=$(echo "$issues_response" | jq -r '.issues[] | select(.fields.parent.key == "'$full_issue_key'") | "\(.id)\t\(.key)\t\(.fields.summary)\t\(.fields.status.name)\t\(.fields.assignee.displayName)\t\(.fields.created)\t\(.fields.issuetype.name)\t\(.fields.labels)\t\(.fields.parent.key)"')
        fi
        # clean up the missing fields
        issue_subtasks=$(echo "$issue_subtasks" | sed 's`\[\]`-`g' | sed 's`null`-`g' | sed 's`\[``g' | sed 's`\]``g')
        # format the date
        issue_subtasks=$(echo "$issue_subtasks" | sed -E 's`(.*)[0-9]{2}([0-9]{2}-[0-9]{2}-[0-9]{2})T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}[\+-]{1}[0-9]{4}(.*)`\1\2\3`')
        header="Id"$'\t'"Key"$'\t'"Summary"$'\t'"Status"$'\t'"Assignee"$'\t'"Created"$'\t'"Issue Type"$'\t'"Labels"$'\t'"Parent"
        # add the header
        issue_subtasks="$header
            $issue_subtasks"
        formatted_issues=$(echo "$issue_subtasks" | awk -F '\t' -v maxlen="$max_summary_length" '
            {
            summary = $3
            if (length(summary) > maxlen) {
                short_summary = substr(summary, 1, maxlen) "..."
                # Reconstruct the line with the truncated summary
                printf "%s\t%s\t%s", $1, $2, short_summary
                for (i = 4; i <= NF; i++) printf "\t%s", $i
                printf "\n"
            } else {
                # Print the line as is
                print
            }
            }')

        # sort and column
        input_header=$(printf '%s\n' "${formatted_issues[@]}" | column -s$'\t' -t | head -n 1 | sed -E 's/^[^[:space:]]+[[:space:]]+//')

        if [ "$show_all" = true ]; then
            # show the 5th column (status)
            issuei="$(printf '%s\n' "$formatted_issues" | tail -n +2 | sort -t '\t' -k 3 -r | column -s$'\t' -t | fzf --header="$input_header" --with-nth=2..)"
        else
            # TODO: make this more robust
            issuei="$(printf '%s\n' "${formatted_issues[@]}" | tail -n +2 | sort -t '\t' -k 2 -r | awk -F '\t' '$4 != "Done" && $4 != "done" && $4 != "Closed" && $4 != "closed"' | column -s$'\t' -t | fzf --header="$input_header" --with-nth=2..)"
        fi
        if [ -z "$issuei" ]; then
            echo "No issue selected"
            return 0
        fi
        issue_num=$(echo "$issuei" | awk '{$1=$1};1' | awk '{print $1}')
        echo -e "\n\033[0;36m\n############## Child ##############\033[0m\n"
        # print the issue, first we get the full issue
        issues_url="https://${repo_owner}.atlassian.net/rest/api/3/issue/$issue_num"
        full_issue=$(curl -s -X GET \
            -H "Authorization: Basic $(echo -n "$jira_email:$jira_api_token" | base64)" \
            -H "Accept: application/json" \
            "$issues_url")

        # Check if the response is valid
        if [[ -z "$full_issue" ]]; then
            echo "Failed to fetch issue."
            return 1
        fi
        full_issue_status=$(echo "$full_issue" | jq -r '.fields.status.name')
        print_issue "$full_issue"
        actions=$transitions
        status=$(printf '%s\n' "${actions[@]}" | fzf --with-nth=3..)
        status_id=$(echo "$status" | awk '{print $1}')
        status_name=$(echo "$status" | awk -F '    ' '{print $3}')
    fi
    if [ "$status_name" == "Show parent" ]; then
        parent_num=$(echo "$full_issue" | jq -r '.fields.parent.id')
        issuei=$(echo "$issues_response" | jq -r '.issues[] | select(.id == "'$parent_num'") | "\(.id)\t\(.key)\t\(.fields.summary)\t\(.fields.status.name)\t\(.fields.assignee.displayName)\t\(.fields.created)\t\(.fields.issuetype.name)\t\(.fields.labels)\t\(.fields.parent.key)"')
        issue_num=$(echo "$issuei" | awk '{$1=$1};1' | awk '{print $1}')
        echo -e "\n\033[0;36m\n############## Parent ##############\033[0m\n"
        # print the issue, first we get the full issue
        issues_url="https://${repo_owner}.atlassian.net/rest/api/3/issue/$issue_num"
        full_issue=$(curl -s -X GET \
            -H "Authorization: Basic $(echo -n "$jira_email:$jira_api_token" | base64)" \
            -H "Accept: application/json" \
            "$issues_url")

        # Check if the response is valid
        if [[ -z "$full_issue" ]]; then
            echo "Failed to fetch issue."
            return 1
        fi
        full_issue_status=$(echo "$full_issue" | jq -r '.fields.status.name')
        print_issue "$full_issue"
        actions=$transitions
        status=$(printf '%s\n' "${actions[@]}" | fzf --with-nth=3..)
        status_id=$(echo "$status" | awk '{print $1}')
        status_name=$(echo "$status" | awk -F '    ' '{print $3}')
    fi
    if [ "$status_name" == "$full_issue_status" ]; then
        echo "No change"
        return 0
    elif [ "$status_name" == "Close issue" ]; then
        check_yes_no_internal "Close issue $full_issue_key? [Y/n]: "
        transit_url="https://${repo_owner}.atlassian.net/rest/api/3/issue/$issue_num/transitions"
        response=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
            -H "Authorization: Basic $(echo -n "$jira_email:$jira_api_token" | base64)" \
            -H "Accept: application/json" \
            -H "Content-Type: application/json" \
            -d "{\"transition\":{\"id\":\"$status_id\"}}" \
            "$transit_url")
        # check if the response is 204
        if [ "$response" == "204" ]; then
            echo "Closed $full_issue_key"
            return 0
        else
            echo "Failed to close $full_issue_key"
            echo "Response: $response"
            return 1
        fi
    elif [ "$status_name" == "Jump to branch" ]; then
        branches="$(compgen -F __git_wrap_git_checkout 2>/dev/null | grep -vE 'HEAD|origin/*|FETCH_HEAD|ORIG_HEAD')"
        branches="$(echo "$branches" | sort -u)"
        branches="$(echo "$branches" | sed 's/^/  /')"
        branch_name="$(echo "$branches" | grep -i $full_issue_key)"
        if [ -z "$branch_name" ]; then
            echo "No branch $full_issue_key found"
            return 0
        fi
        # if $branch_name has multiple lines
        if [ "$(echo "$branch_name" | wc -l)" -gt 1 ]; then
            # let the user choose the branch
            branch_name=$(printf '%s\n' "${branch_name[@]}" | fzf)
            # strip whitespace
            if [ -z "$branch_name" ]; then
                echo "No branch selected"
                return 0
            fi
        fi
        # strip whitespace
        branch_name=$(echo "$branch_name" | sed 's/^[[:space:]]*//')
        git checkout $branch_name
        return 0
    #  let the user choose the assignees
    elif [ "$status_name" == "Assign" ]; then
        #     # get people on the project
        # let the user enter the assignee in the command line, listen for enter
        assignee=$(printf '%s\n' "${people_names[@]}" | fzf)
        if [ -z "$assignee" ]; then
            echo "No assignee selected"
            return 0
        else
            line_number=$(echo "$people_names" | grep -n "$assignee" | cut -d ":" -f 1)
            if [[ -n "$line_number" ]]; then
                matched_assignee_index=$((line_number))
                assignee_id=$(echo "$people_ids" | head -n $matched_assignee_index | tail -n 1)

                # echo "Assigning $assignee with id $assignee_id to $full_issue_key"

                assign_url="https://${repo_owner}.atlassian.net/rest/api/3/issue/$issue_num/assignee"
                response=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
                    -H "Authorization: Basic $(echo -n "$jira_email:$jira_api_token" | base64)" \
                    -H "Accept: application/json" \
                    -H "Content-Type: application/json" \
                    -d "{\"accountId\":\"$assignee_id\"}" \
                    "$assign_url")
                # check if the response is 204
                if [ "$response" == "204" ]; then
                    echo "Assigned $assignee to $full_issue_key"
                    return 0
                else
                    echo "Failed to assign $assignee to $full_issue_key"
                    echo "Response: $response"
                    return 1
                fi
            else
                echo "No assignee found"
                return 0
            fi
        fi
    fi

    if [ -z "$status_name" ]; then
        echo "No status selected"
        return 0
    # if the ticket goes into In Progress, we want to create a branch, but only if it's not a nocode or epic ticket
    elif { [ "$status_name" == "In Progress" ] || [ "$status_name" == "in progress" ]; } && [ -z "$(echo "$full_issue_labels" | grep -E "nocode|epic")" ]; then
        #remove  [0-9]+ from $full_issue_key and $full_issue_summary, those are the storypoints
        issue_name=$(echo $full_issue_summary | sed 's/^\[[0-9]\+\] //')
        branch_name=$full_issue_key"-"$issue_name
        # remove all " - " from the branch name
        branch_name=$(echo "$branch_name" | sed 's` - ` `g')
        #substitute all spaces with dashes
        branch_name=${branch_name// /-}
        # remove all non-alphanumeric characters
        branch_name=${branch_name//[^a-zA-Z0-9-]/}
        # check if feature hotfix bugfix or test are in the labels
        full_issue_issuetype=$(echo "$full_issue" | jq -r '.fields.issuetype.name')
        branch_type=""
        # priority is: hotfix > bugfix > test > feature > spike
        # labels are more important than issue type
        if [ "$(echo "$full_issue_issuetype" | grep -i "task")" != "" ] || [ "$(echo "$full_issue_issuetype" | grep -i "subtask")" != "" ] || [ "$(echo "$full_issue_issuetype" | grep -i "epic")" != "" ]; then
            branch_type="feature/"
        fi
        if [ "$(echo "$full_issue_issuetype" | grep -i "spike")" != "" ]; then
            branch_type="spike/"
        fi
        if [ "$(echo "$full_issue_labels" | grep -i "feature")" != "" ]; then
            branch_type="feature/"
        fi
        if [ "$(echo "$full_issue_labels" | grep -i "test")" != "" ]; then
            branch_type="test/"
        fi
        if [ "$(echo "$full_issue_labels" | grep -i "bugfix")" != "" ] || [ "$(echo "$full_issue_issuetype" | grep -i "bug")" != "" ]; then
            branch_type="bugfix/"
        fi
        if [ "$(echo "$full_issue_labels" | grep -i "hotfix")" != "" ]; then
            branch_type="hotfix/"
        fi

        # add the prefix
        branch_name=$branch_type$branch_name
        # convert to lowercase
        branch_name=${branch_name,,}
        # check if branch exists
        if [ -z "$(git branch --list | grep " $branch_name"$)" ]; then
            if check_yes_no_internal "It's dangerous to go alone! Take a branch with you? [Y/n]: "; then
                #make sure we are on main or dev
                #check if dev exists
                if [ -z "$(git branch --list | grep " dev$")" ]; then
                    if [ "$(git branch --show-current)" != "main" ]; then
                        if check_yes_no_internal "You are not on main, switch to main and pull before creating branch? [Y/n]: "; then
                            git checkout main
                            git pull
                        elif ! check_yes_no_internal "Continue without switching to main? [Y/n]: "; then
                            echo "Aborting"
                            return 0
                        fi
                    fi
                else
                    if [ "$(git branch --show-current)" != "dev" ]; then
                        if check_yes_no_internal "You are not on dev, switch to dev and pull before creating branch? [Y/n]: "; then
                            git checkout dev
                            git pull
                        elif ! check_yes_no_internal "Continue without switching to dev? [Y/n]: "; then
                            echo "Aborting"
                            return 0
                        fi
                    fi
                fi
                git checkout -b $branch_name
            fi
        elif [ "$(git branch --show-current)" != "$branch_name" ]; then
            if check_yes_no_internal "Switch to $branch_name? [Y/n]: "; then
                git checkout $branch_name
            fi
        fi
    fi
    # move the ticket to the new status
    transit_url="https://${repo_owner}.atlassian.net/rest/api/3/issue/$issue_num/transitions"
    response=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
        -H "Authorization: Basic $(echo -n "$jira_email:$jira_api_token" | base64)" \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -d "{\"transition\":{\"id\":\"$status_id\"}}" \
        "$transit_url")
    # check if the response is 204
    if [ "$response" == "204" ]; then
        echo "Moved $full_issue_key to $status_name"
        return 0
    else
        echo "Failed to move $full_issue_key to $status_name"
        echo "Response: $response"
        return 1
    fi

    return 0
}
