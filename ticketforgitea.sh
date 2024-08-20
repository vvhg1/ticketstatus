#!/bin/bash

# This script is used to manage github tickets in a project
ticketforgitea() {
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
        echo "ticketforgitea"
        echo "Checks and changes the status of tickets on github"
        echo "The tickets will be checked in the current directory's git repo"
        echo ""
        echo "Usage: ttik [flags]"
        echo ""
        echo "Flags"
        echo ""
        echo "-h, --help: Show help"
        echo ""
        echo "-a, --all: Show all tickets, otherwise don't show done tickets"
        ehco ""
        echo "-l, --list: List all tickets in the current project"
        echo ""
        echo "-o, --options: Show all status options"
        echo ""
        echo "Tickets can be searched by fuzzy searching"
        echo "Selecting a ticket will move on to the next step where you can manipulate the ticket"
        echo "The ticket can be moved to a different status column, or closed"
        echo "The ticket can be assigned to a user, @me will assign it to you"
        return 0
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
        -o | --options)
            all_options=true
            ;;
        -la | -al)
            show_all=true
            only_list=true
            ;;
        -lo | -ol)
            only_list=true
            all_options=true
            ;;
        -ao | -oa)
            show_all=true
            all_options=true
            ;;
        -lao | -loa | -alo | -aol | -ola | -oal)
            show_all=true
            only_list=true
            all_options=true
            ;;
        *)
            echo "Invalid flag $arg"
            return 1
            ;;
        esac
    done

    if [ $show_all = true ]; then
        show_issues="all"
    else
        show_issues="open"
    fi

    # check if token is set
    if [ -z "$TEA_TOKEN" ]; then
        # let th user enter the token and set it
        read -sp "Please enter your token: " my_token
        echo
    fi
    # set the token
    export TEA_TOKEN="$my_token"
    
    gh_name=$(git config user.name)
    
    touch "/tmp/$gh_name.tea_cookies.txt"
    chmod 600 "/tmp/$gh_name.tea_cookies.txt"
    
    repo_url=$(git remote get-url origin)
    repo_url=$(echo $repo_url | sed -E 's/(https:\/\/|git@)//g' | sed -E 's/(\/|:).*//')

    repo_owner=$(git remote get-url origin | sed -E 's/(https:\/\/|git@)([a-zA-Z0-9\-\.]*)(:|\/)//g' | sed 's/\/.*//')
    
    repo_name=$(basename $(git rev-parse --show-toplevel))

    get_login_page=$(curl -s -i -k 'GET' \
    'https://'"$repo_url"'/user/login' \
    -c "/tmp/$gh_name.tea_cookies.txt" \
    -b "/tmp/$gh_name.tea_cookies.txt" \
    -H 'accept: text/html,application/xhtml+xml,application/xml')
    
    # this gets the repo and it's projects
    get_project_request=$(curl -s -i -k 'GET' \
        'https://'"$repo_url"'/'"$repo_owner"'/'"$repo_name"'/projects' \
        -b "/tmp/$gh_name.tea_cookies.txt" \
        -c "/tmp/$gh_name.tea_cookies.txt" \
        -H 'accept: text/html,application/xhtml+xml,application/xml' 
    )
    
    # get response code
    response_code=$(echo "$get_project_request" | grep -oP "HTTP\/[0-9\.]+ \K[0-9]{3}" | head -n 1)
    if [ "$response_code" == "404" ]; then # if we get a 404 then we need to login
        echo "You need to login to Gitea"
        # ask for password
        read -sp "Please enter your gitea password:" gtpw
        # new line
        echo
          login_response=$(curl -s -i -L 'https://'"$repo_url"'/user/login' \
          -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7' \
          -H 'Content-Type: application/json' \
          -b "/tmp/$gh_name.tea_cookies.txt" \
          -c "/tmp/$gh_name.tea_cookies.txt" \
          -d '{
              "UserName": "'"$gh_name"'",
              "Password": "'"$gtpw"'"
          }' \
          --compressed \
          --insecure)
        response_code=$(echo "$login_response" | grep -oP "HTTP\/[0-9\.]+ \K[0-9]{3}" | head -n 1)
        echo "Login response code $response_code"
        if [ "$response_code" != "303" ]; then
            echo "Login failed"
            echo "$login_response"
            return 1
        fi
        if [ $(echo "$login_response" | wc -l) -lt 350 ]; then
            echo "Login failed, page too short"
            echo "$login_response"
            return 1
        fi
        
        get_project_request=$(curl -s -i -k 'GET' \
            'https://'"$repo_url"'/'"$repo_owner"'/'"$repo_name"'/projects' \
            -H 'accept: text/html,application/xhtml+xml,application/xml' \
            -b "/tmp/$gh_name.tea_cookies.txt" \
            -c "/tmp/$gh_name.tea_cookies.txt" \
        )
        

    fi
    project_id=$(echo $get_project_request | grep -oP 'href=".*projects\/\K\d+' | head -n 1)

    
    issues=$(curl -s -k 'GET' \
      'https://'"$repo_url"'/api/v1/repos/'"$repo_owner"'/'"$repo_name"'/issues?state='"$show_issues"'' \
      -H 'accept: application/json' \
      -H 'Authorization: token '"$my_token" \
      -H 'Content-Type: application/json')
    
    # now we need to get the issues from the project page to get the columns
    get_project_page=$(curl -s -i -k 'GET' \
        'https://'"$repo_url"'/'"$repo_owner"'/'"$repo_name"'/projects/'"$project_id"'' \
        -H 'Accept: text/html,application/xhtml+xml,application/xml' \
        -b "/tmp/$gh_name.tea_cookies.txt" \
        -c "/tmp/$gh_name.tea_cookies.txt" \
        )

    column_ids=$(echo "$get_project_page" | grep "ui segment project-column" | sed -E 's/.*data-id=\"([0-9]+)\".*/\1/')
    column_names=$(echo "$get_project_page" | grep -A 3 "project-column-issue-count" | grep -v "project-column-issue-count" | grep -v "\-\-" | grep -vE "[0-9]+" | grep -v "<\/div>" | sed 's/^[[:space:]]*//')

    combined_cols=$(paste -d ',' <(echo "$column_names") <(echo "$column_ids"))
    colunns_headers=$(echo "$get_project_page" | grep -n -oP "project-column-issue-count\">" | cut -d ":" -f 1 | tac)
    # we build a json array of issues
    issues_to_columns="[]"
    while IFS= read -r colunn_header; do
            colunn_name=$(echo "$get_project_page" | tail -n +"$((colunn_header + 3))" | head -n 1 | sed 's/^[[:space:]]*//g')
            # now we get the issues
            issues_section=$(echo "$get_project_page" | tail -n +"$((colunn_header + 3))")
            # the project page has the issues listed in the following format
            issues_numbers=$(echo "$issues_section" | grep -oP 'href="/'"$repo_owner"'/'"$repo_name"'/issues/\K\d+')
            if [ -z "$issues_numbers" ]; then
                continue
            fi
            # now we add the issues to the array
            while IFS= read -r issue; do
                # add the issue to the issues_to_columns array
                issue_to_add="{\"number\":$issue,\"issueState\":\"$colunn_name\"}"
                issues_to_columns=$(echo "$issues_to_columns" | jq  ". += [$issue_to_add]")
            done <<< "$issues_numbers"
            # cut that section out of the page
            get_project_page=$(echo "$get_project_page" | head -n $((colunn_header + 3)))
    done <<< "$colunns_headers"
    

    # Combine issues and issues_to_columns
    combined_issues=$(jq -n --argjson issues "$issues" --argjson issues_to_columns "$issues_to_columns" ' [$issues[] as $i | $issues_to_columns[] | select(.number == $i.number) | $i + {issueState: .issueState}] ')
    
    # if only listing, print and exit
    if [ "$only_list" = true ]; then
        if [ "$show_all" = true ]; then
            # we now use the combined issues array
            echo "$combined_issues" | jq -r '
              .[] | {
                number, 
                title, 
                issueState, 
                labels: (if .labels then (.labels | map(.name) | join(",")) else "-" end), 
                state, 
                assignees: (if .assignees | length > 0 then (.assignees | map(.username) | join(",")) else "-" end), 
                createdAt
              } | "\(.number);\(.title);\(.issueState);\(.labels);\(.state);\(.assignees);\(.createdAt)"
            ' | sed 's/null/-/g' | sort -t ';' -k 3 -r | column -s$';' -t
        else
            echo "$combined_issues" | jq -r '
              .[] | {
                number, 
                title, 
                issueState, 
                labels: (if .labels then (.labels | map(.name) | join(",")) else "-" end), 
                state, 
                assignees: (if .assignees | length > 0 then (.assignees | map(.username) | join(",")) else "-" end), 
                createdAt
              } | "\(.number);\(.title);\(.issueState);\(.labels);\(.state);\(.assignees);\(.createdAt)"
            ' | sed 's/null/-/g' | sort -t ';' -k 3 -r | awk -F ';' '$3 != "Done" && $3 != "done"' | column -s$';' -t
        fi
        return 0
    fi
    # print the issues
    if [ "$show_all" = true ]; then
        # show the 5th column (status)
        issuei="$(echo "$combined_issues" | jq -r '.[] | "\(.number);\(.title);\(.issueState);\(.labels[].name);\(.state);\(if (.assignees | length > 0) then (.assignees[] | map(.username) | join(", ")) else "-" end);\(.created_at)"' | sed 's/null/-/g' | sort -t ';' -k 3 -r | column -s$';' -t | fzf)"
    else
        issuei="$(echo "$combined_issues" | jq -r '.[] | "\(.number);\(.title);\(.issueState);\(.labels | map(.name) | join(", "));\(.state);\(if (.assignees | length > 0) then(.assignees | map(.username) | join(", ")) else "-" end);\(.created_at)"' | sed 's/null/-/g' | sort -t ';' -k 3 -r | awk -F ';' '$3 != "Done" && $3 != "done"' | column -s$';' -t | fzf)"
    fi
    if [ -z "$issuei" ]; then
        echo "No issue selected"
        return 0
    fi
    issue_num=${issuei%% *}
    # we grab the issue from the combined issues json, we know it's number is $issue_num and it is at the beginning of the line
    full_issue=$(echo "$combined_issues" | jq -r '.[] | "\(.number);\(.title);\(.issueState);\(.labels | map(.name) | join(", "));\(.state);\(if (.assignees | length > 0) then(.assignees | map(.username) | join(", ")) else "-" end);\(.created_at);\(.repository.full_name);\(.url);\(.body);\(.id)"' | sed 's/null/-/g' | grep -w "^$issue_num")
    issue_id=$(echo "$full_issue" | awk -F ';' '{print $11}')
    # | column -s$';' -t)
    issue_body=$(echo "$full_issue" | awk -F ';' '{print $10}')
    indent="    "  # 4 spaces
    indented_body=$(echo "$issue_body" | fold -s -w 80 | sed "s/^/$indent/")

    # dark grey color for the hyperlinks
    grey="\033[38;5;240m"
    # reset color
    reset="\033[0m"
    hyperlink="$grey$(echo "$full_issue" | awk -F ';' '{print $9}')$reset"

    # print the issue nicely, first line is the issue title, repo name and number, second line is the issue body
    echo "$full_issue" | awk -v indented_body="$indented_body" -v hyperlink="$hyperlink" -F ';' '{printf "\033[1m%s\033[0m %s#%s\n%s - %s\n\nAssignees: %s\n\n%s\n\n%s\n", $2, $8, $1, $5, $3, $6,indented_body, hyperlink}'

    
    # get the state
    issue_state=$(echo "$full_issue" | awk -F ';' '{print $5}')
    issue_name="$(echo "$full_issue" | awk -F ';' '{print $2}')"
    current_column="$(echo "$full_issue" | awk -F ';' '{print $3}')"
    
    # full status options are the columns, Assign, Jump to branch, Close issue
    # light status options are only sprint backlog and in progress
    full_status_options="none;Assign\nnone;Jump to branch\nnone"
    if [ "$issue_state" != "CLOSED" ] && [ "$issue_state" != "closed" ] && [ "$issue_state" != "Closed" ]; then
        full_status_options="$full_status_options\nnone;Close issue"
    fi
    while IFS= read -r col; do
        col_name=$(echo "$col" | cut -d ',' -f 1)
        col_id=$(echo "$col" | cut -d ',' -f 2)
        if [ "$col_name" != "$current_column" ]; then
            full_status_options="$full_status_options\n$col_id;$col_name"
        fi
    done <<< "$combined_cols"
    
    

    light_status_options="none;Jump to branch"
    while IFS= read -r col; do
        col_name=$(echo "$col" | cut -d ',' -f 1)
        col_id=$(echo "$col" | cut -d ',' -f 2)
        if [ "$col_name" != "$current_column" ]; then
            if [ "$col_name" == "sprint backlog" ] || [ "$col_name" == "Sprint Backlog" ] || [ "$col_name" == "in progress" ] || [ "$col_name" == "In Progress" ]; then
                light_status_options="$light_status_options\n$col_id;$col_name"
            fi
        fi
    done <<< "$combined_cols"

    if [ "$all_options" = true ]; then
        status_options="$full_status_options"
    else
        status_options="$light_status_options"
    fi

    
    status=$(echo -e "$status_options" | cut -d ';' -f 2 | tac | fzf)
    # selected_status_id=$(echo -e "$status_options" | grep -w "$status" | cut -d ';' -f 1)
    selected_status_id=$(echo -e "$combined_cols" | grep -e "^$status," | cut -d ',' -f 2)
    
    if [ -z "$status" ]; then
        echo "No status selected"
        return 0
    elif [ "$status" == "Close issue" ] || [ "$status" == "done" ] || [ "$status" == "Done" ]; then
        check_yes_no_internal "Close issue $issue_name? [Y/n]: "
        issue_closed=$(curl -s -i -k -X 'PATCH' \
        'https://'"$repo_url"'/api/v1/repos/'"$repo_owner"'/'"$repo_name"'/issues/'"$issue_num"'' \
        -H 'Authorization: token '"$my_token" \
        -H 'accept: application/json' \
        -H 'Content-Type: application/json' \
        -d '{
            "state": "closed"
        }' \
        )
        closed_col_id=$(echo "$combined_cols" | grep -e "[d,D]one" | cut -d ',' -f 2)
        csrf_token=$(cat "/tmp/$gh_name.tea_cookies.txt" | grep _csrf | awk {'print $7'})
        add_to_done=$(curl -s -k -X 'POST' \
            'https://'"$repo_url"'/'"$repo_owner"'/'"$repo_name"'/projects/'"$project_id"'/'"$closed_col_id"'/move' \
            -H 'X-Csrf-Token: '"$csrf_token"'' \
            -c "/tmp/$gh_name.tea_cookies.txt" \
            -b "/tmp/$gh_name.tea_cookies.txt" \
            -H 'accept: application/json' \
            -H 'Content-Type: application/json' \
            -d '{
                "issues": [
                    {
                        "issueID": '"$issue_id"',
                        "sorting": 0
                    }
                ]
            }')
        if [ "$add_to_done" != "{\"ok\":true}" ]; then
            echo "Error adding issue to column"
            echo "$add_to_done"
            return 1
        fi
        echo "Closed issue $issue_name"

        return 0
    elif [ "$status" == "Jump to branch" ]; then
        branches="$(compgen -F __git_wrap_git_checkout 2>/dev/null | grep -vE 'HEAD|origin/*|FETCH_HEAD|ORIG_HEAD')"
        branches="$(echo "$branches" | sort -u)"
        branches="$(echo "$branches" | sed 's/^/  /')"
        branch_name="$(echo "$branches" | grep $issue_num)"
        if [ -z "$branch_name" ]; then
            echo "No branch $branch_name found"
            return 0
        fi
        git checkout $branch_name
        return 0
    #  let the user choose the assignees
    elif [ "$status" == "Assign" ]; then
        all_people=$(curl -s -k 'GET' \
            'https://'"$repo_url"'/api/v1/repos/'"$repo_owner"'/'"$repo_name"'/assignees' \
            -H 'accept: application/json' \
            -H 'Authorization: token '"$my_token")
        # let the user choose the assignee
        assignee=$(echo "$all_people" | jq -r '.[] | "\(.username)"' | sed 's/null/-/g' | sort -t ';' -k 2 -r | column -s$';' -t | fzf)
        if [ -z "$assignee" ]; then
            echo "No assignee selected"
            return 0
        fi
        assignee_id=$(echo "$all_people" | jq --arg username "$assignee" '.[] | select(.username == $username) | .id')
        
        existing_assignees=$(echo "$combined_issues" | jq -r '.[] | "\(.number);\(.assignees)"' | grep -w "^$issue_num" | awk -F ';' '{print $2}')
        # if not null, then we have assignees
        if [ -n "$(echo "$existing_assignees" | grep -w "$assignee")" ]; then
            echo "Assignee already assigned"
            return 0
        fi
        #we add the assignee
        csrf_token=$(cat "/tmp/$gh_name.tea_cookies.txt" | grep _csrf | awk {'print $7'})
        adding_assignee=$(curl -s -k 'https://'"$repo_url"'/'"$repo_owner"'/'"$repo_name"'/issues/assignee' \
          -H 'Accept: application/json' \
          -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' \
          -b "/tmp/$gh_name.tea_cookies.txt" \
          -c "/tmp/$gh_name.tea_cookies.txt" \
          --data-raw '_csrf='"$csrf_token"'&action=attach&issue_ids='"$issue_id"'&id='"$assignee_id"'' \
        )
        if [ "$adding_assignee" != "{\"ok\":true}" ]; then
            echo "Error adding assignee"
            echo "$adding_assignee"
            return 1
        fi
        return 0
    else
        
        csrf_token=$(cat "/tmp/$gh_name.tea_cookies.txt" | grep _csrf | awk {'print $7'})
        add_to_col=$(curl -s -k -X 'POST' \
            'https://'"$repo_url"'/'"$repo_owner"'/'"$repo_name"'/projects/'"$project_id"'/'"$selected_status_id"'/move' \
            -H 'X-Csrf-Token: '"$csrf_token"'' \
            -c "/tmp/$gh_name.tea_cookies.txt" \
            -b "/tmp/$gh_name.tea_cookies.txt" \
            -H 'accept: application/json' \
            -H 'Content-Type: application/json' \
            -d '{
                "issues": [
                    {
                        "issueID": '"$issue_id"',
                        "sorting": 0
                    }
                ]
            }')
            # should return {"ok":true}
        if [ "$add_to_col" != "{\"ok\":true}" ]; then
            echo "Error adding issue to column"
            echo "selected_status_id $selected_status_id"
            echo "$add_to_col"
            return 1
        fi
            
        if [[ "$status" != *"acklog" ]] && [ -z "$(echo "$full_issue" | grep "nocode\|epic")" ]; then
            #remove  [0-9]+ from $issue_name
            issue_name=$(echo $issue_name | sed 's/^\[[0-9]\+\] //')
            branch_name=$issue_num"-"$issue_name
            #substitute all spaces with dashes
            branch_name=${branch_name// /-}
            # remove all non-alphanumeric characters
            branch_name=${branch_name//[^a-zA-Z0-9-]/}
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
    fi

    return 0
}
