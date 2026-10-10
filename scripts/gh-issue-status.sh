#!/usr/bin/env bash
# Usage: scripts/gh-issue-status.sh <issue> [<new-status> [--if <current-status>]]
# Prints the issue's Status in the "Shift Planner" project; with <new-status>, moves it there.
# --if only moves it when the current Status matches (e.g. only from "Backlog").
set -euo pipefail

OWNER=frcalderon
REPO=shift-planner-backend
PROJECT_ID=PVT_kwHOAd81yM4Bl0jY
STATUS_FIELD_ID=PVTSSF_lAHOAd81yM4Bl0jYzhkf3pc

issue=${1:?issue number required}
target=${2:-}
expected=""
[[ ${3:-} == "--if" ]] && expected=${4:?status required after --if}

option_id() {
  case "$1" in
    "Backlog") echo f75ad846 ;;
    "In progress") echo 47fc9ee4 ;;
    "In review") echo df73e18b ;;
    "Done") echo 98236657 ;;
    *) echo "Unknown status: $1 (Backlog | In progress | In review | Done)" >&2; exit 1 ;;
  esac
}

read -r item_id current < <(gh api graphql -f query='
  query($owner: String!, $repo: String!, $issue: Int!) {
    repository(owner: $owner, name: $repo) {
      issue(number: $issue) {
        projectItems(first: 10) {
          nodes { id project { id } fieldValueByName(name: "Status") { ... on ProjectV2ItemFieldSingleSelectValue { name } } }
        }
      }
    }
  }' -f owner=$OWNER -f repo=$REPO -F issue="$issue" \
  --jq ".data.repository.issue.projectItems.nodes[] | select(.project.id == \"$PROJECT_ID\") | \"\(.id) \(.fieldValueByName.name // \"none\")\"")

if [[ -z ${item_id:-} ]]; then
  echo "Issue #$issue is not in the project" >&2
  exit 1
fi

if [[ -z $target ]]; then
  echo "$current"
  exit 0
fi

if [[ -n $expected && $current != "$expected" ]]; then
  echo "Issue #$issue is in '$current', not '$expected': left unchanged"
  exit 0
fi

gh project item-edit --id "$item_id" --project-id $PROJECT_ID --field-id $STATUS_FIELD_ID \
  --single-select-option-id "$(option_id "$target")" > /dev/null
echo "Issue #$issue: $current -> $target"
