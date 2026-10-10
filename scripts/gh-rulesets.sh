#!/usr/bin/env bash
# Usage: scripts/gh-rulesets.sh
# Creates or updates the branch rulesets of develop and main: PR with merge commit required, no force-push or deletion,
# and the CI checks must pass. Only the release bot (GitHub App) may bypass main, to push the release commit.
set -euo pipefail

REPO=frcalderon/shift-planner-backend
RELEASE_APP_ID=5262413
GITHUB_ACTIONS_APP_ID=15368

ruleset() {
  local name=$1 checks=$2 bypass=$3
  cat <<EOF
{
  "name": "$name",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["refs/heads/$name"], "exclude": [] } },
  "bypass_actors": $bypass,
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false,
        "allowed_merge_methods": ["merge"]
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": false,
        "do_not_enforce_on_create": false,
        "required_status_checks": $checks
      }
    }
  ]
}
EOF
}

check() {
  printf '{ "context": "%s", "integration_id": %s }' "$1" "$GITHUB_ACTIONS_APP_ID"
}

apply() {
  local name=$1 body=$2 id
  id=$(gh api "repos/$REPO/rulesets" --jq ".[] | select(.name == \"$name\") | .id")
  if [[ -n $id ]]; then
    gh api --method PUT "repos/$REPO/rulesets/$id" --input - <<< "$body" > /dev/null
    echo "Updated ruleset $name ($id)"
  else
    gh api --method POST "repos/$REPO/rulesets" --input - <<< "$body" > /dev/null
    echo "Created ruleset $name"
  fi
}

unit=$(check "Build and unit tests")
integration=$(check "integration-tests / Integration tests")
release_bot="[{ \"actor_id\": $RELEASE_APP_ID, \"actor_type\": \"Integration\", \"bypass_mode\": \"always\" }]"

apply develop "$(ruleset develop "[$unit]" "[]")"
apply main "$(ruleset main "[$unit, $integration]" "$release_bot")"
