#!/usr/bin/env bash
set -Eeuo pipefail

RUNNER_TEMP="${RUNNER_TEMP:-/tmp}"
HISTORY="$RUNNER_TEMP/tube-arena-repair-history.md"
printf '# Tube Arena automated repair history\n\n' > "$HISTORY"

EXPECTED_BRANCH="feature/complete-tube-arena"
REPO="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
BRANCH="${GITHUB_REF_NAME:?GITHUB_REF_NAME is required}"
GH_TOKEN="${GH_TOKEN:?GH_TOKEN is required for CI dispatch and feature-branch commits}"
COPILOT_GITHUB_TOKEN="${COPILOT_GITHUB_TOKEN:-}"
RUNNER_TEMP="${RUNNER_TEMP:-/tmp}"

if [[ "$BRANCH" != "$EXPECTED_BRANCH" ]]; then
  echo "::error::Refusing to repair branch '$BRANCH'. Only '$EXPECTED_BRANCH' is allowed."
  exit 1
fi

if [[ -z "$COPILOT_GITHUB_TOKEN" ]]; then
  echo "::error::Missing repository secret COPILOT_GITHUB_TOKEN."
  echo "Create a fine-grained personal access token with Copilot Requests: Read, then add it under Settings > Secrets and variables > Actions."
  {
    echo "## Final result"
    echo
    echo "**BLOCKED** — the repair agent has no Copilot credential. Add the COPILOT_GITHUB_TOKEN repository secret to enable automatic repairs."
  } >> "$GITHUB_STEP_SUMMARY"
  exit 78
fi

command -v gh >/dev/null
command -v jq >/dev/null
command -v copilot >/dev/null


find_run() {
  local sha="$1"
  gh run list --workflow android-ci.yml --branch "$BRANCH" --limit 100 \
    --json databaseId,headSha,status,conclusion,event,createdAt |
    jq -c --arg sha "$sha" '[.[] | select(.headSha == $sha)] | sort_by(.createdAt) | last // empty'
}

run_snapshot() {
  local run_id="$1"
  gh run view "$run_id" --repo "$REPO" \
    --json databaseId,headSha,status,conclusion,event
}

wait_for_run() {
  local run_id="$1"
  local expected_sha="$2"
  local record status conclusion actual_sha
  while true; do
    record="$(run_snapshot "$run_id")"
    actual_sha="$(jq -r '.headSha' <<< "$record")"
    if [[ "$actual_sha" != "$expected_sha" ]]; then
      echo "::error::Run $run_id targets $actual_sha, expected $expected_sha."
      return 2
    fi
    status="$(jq -r '.status' <<< "$record")"
    if [[ "$status" == "completed" ]]; then
      conclusion="$(jq -r '.conclusion // "unknown"' <<< "$record")"
      printf '%s\n' "$run_id" > "$RUNNER_TEMP/tube-arena-last-ci-run-id"
      printf '%s\n' "$conclusion" > "$RUNNER_TEMP/tube-arena-last-ci-conclusion"
      printf -- '- Commit `%s`: Android CI run [%s](https://github.com/%s/actions/runs/%s) — **%s**\\n' \
        "$expected_sha" "$run_id" "$REPO" "$run_id" "$conclusion" >> "$HISTORY"
      case "$conclusion" in
        success) return 0 ;;
        cancelled) return 3 ;;
        *) return 1 ;;
      esac
    fi
    echo "Waiting for exact Android CI run $run_id (status: $status)."
    sleep 15
  done
}

dispatch_new_ci() {
  local sha="$1"
  local before_ids record run_id
  before_ids="$(gh run list --workflow android-ci.yml --branch "$BRANCH" --limit 100 --json databaseId | jq -r '.[].databaseId' | sort -n)"
  echo "Dispatching a fresh Android CI run for exact commit $sha." >&2
  gh workflow run android-ci.yml --repo "$REPO" --ref "$BRANCH"
  for attempt in $(seq 1 60); do
    record="$(gh run list --workflow android-ci.yml --branch "$BRANCH" --limit 100 \
      --json databaseId,headSha,status,conclusion,event,createdAt |
      jq -c --arg sha "$sha" --arg before "$(printf '%s' "$before_ids" | paste -sd, -)" '
        ($before | split(",") | map(select(length > 0))) as $ids
        | [.[] | select(.headSha == $sha and .event == "workflow_dispatch")
          | select((.databaseId | tostring) as $id | ($ids | index($id)) == null)]
        | sort_by(.createdAt) | last // empty' 2>/dev/null || true)"
    if [[ -n "$record" ]]; then
      run_id="$(jq -r '.databaseId' <<< "$record")"
      echo "Captured newly dispatched Android CI run $run_id for $sha." >&2
      printf '%s\n' "$run_id"
      return 0
    fi
    sleep 10
  done
  echo "::error::The dispatched Android CI run for $sha did not appear within 10 minutes." >&2
  return 2
}

wait_for_ci() {
  local sha="$1"
  local record run_id status conclusion dispatch_status

  # Prefer an existing exact-SHA run. A cancelled run is not treated as a code
  # failure: dispatch one fresh run and then follow that run ID only.
  record="$(find_run "$sha")"
  if [[ -n "$record" ]]; then
    run_id="$(jq -r '.databaseId' <<< "$record")"
    status="$(jq -r '.status' <<< "$record")"
    conclusion="$(jq -r '.conclusion // ""' <<< "$record")"
    if [[ "$status" == "completed" && "$conclusion" == "cancelled" ]]; then
      echo "Latest exact-SHA CI run $run_id was cancelled; requesting one replacement run."
      run_id="$(dispatch_new_ci "$sha")" || return 2
    fi
  else
    run_id="$(dispatch_new_ci "$sha")" || return 2
  fi

  if wait_for_run "$run_id" "$sha"; then
    return 0
  else
    dispatch_status=$?
  fi

  # One cancellation recovery only. Never loop on repeated cancellations.
  if [[ "$dispatch_status" -eq 3 ]]; then
    echo "CI run $run_id was cancelled; requesting one controlled replacement."
    run_id="$(dispatch_new_ci "$sha")" || return 2
    wait_for_run "$run_id" "$sha"
    return $?
  fi
  return "$dispatch_status"
}

iteration=0
target_sha="${GITHUB_SHA:?GITHUB_SHA is required}"

while true; do
  iteration=$((iteration + 1))
  echo
  echo "========== Tube Arena repair cycle $iteration =========="
  echo "Target branch: $BRANCH"
  echo "Target commit: $target_sha"

  if wait_for_ci "$target_sha" true; then
    echo "All required Android CI checks passed."
    {
      echo
      echo "## Final result"
      echo
      echo "**SUCCESS** — Android CI passed for commit `$target_sha`."
      cat "$HISTORY"
    } >> "$GITHUB_STEP_SUMMARY"
    exit 0
  else
    ci_status=$?
  fi

  if [[ "$ci_status" -eq 3 ]]; then
    exit 1
  fi
  if [[ "$ci_status" -eq 2 ]]; then
    exit 1
  fi

  run_id="$(cat "$RUNNER_TEMP/tube-arena-last-ci-run-id")"
  failure_log="$RUNNER_TEMP/tube-arena-ci-failure-$iteration.log"
  agent_log="$RUNNER_TEMP/tube-arena-copilot-$iteration.log"

  echo "Collecting failed CI logs from run $run_id."
  gh run view "$run_id" --repo "$REPO" --log-failed > "$failure_log" 2>&1 || true
  if [[ ! -s "$failure_log" ]]; then
    echo "::error::GitHub returned no failure logs for run $run_id. Stopping for manual investigation."
    exit 1
  fi

  git reset --hard
  git clean -fd

  prompt="$(cat <<PROMPT
You are the primary repair agent for the Flutter Android app Tube Arena.
Repository: $REPO
Branch: $BRANCH
Failing Android CI run: $run_id
Failure log: $failure_log

Your task:
1. Read the complete failure log and identify the first real root cause, not unrelated warnings.
2. Inspect the relevant Dart, Flutter, Android/Kotlin, Gradle, manifest, and test files.
3. Make the smallest safe source/configuration repair supported by evidence.
4. Do not commit, push, create branches, or change any GitHub Actions workflow.
5. Never disable, skip, delete, weaken, or loosen tests, assertions, analyzer rules, permissions, or smoke-test checks merely to make CI green.
6. Do not add a YouTube API key or any paid YouTube API dependency.
7. Do not make unrelated feature changes.
8. If no safe, evidence-based fix can be made, make no changes and explain why.

Allowed change areas: lib/, test/, android/, pubspec.yaml, pubspec.lock, analysis_options.yaml, and tool/bootstrap_android.sh.
Do not edit files under .github/ or any other paths.
Do not claim success without a real code change. The workflow will rerun the complete Android CI after your patch.

Use the available read, write, and shell tools as needed. Do not ask the user questions; this is a non-interactive repair task.
PROMPT
)"

  echo "Starting Copilot CLI diagnosis and repair."
  if ! env -u GH_TOKEN -u GITHUB_TOKEN COPILOT_GITHUB_TOKEN="$COPILOT_GITHUB_TOKEN" \
      copilot -p "$prompt" --allow-tool='shell, write' --no-ask-user \
      > "$agent_log" 2>&1; then
    cat "$agent_log"
    echo "::error::Copilot could not complete the repair attempt. Stopping."
    exit 1
  fi

  cat "$agent_log"
  git add -N . 2>/dev/null || true
  changed_files="$(git diff --name-only)"
  if [[ -z "$changed_files" ]]; then
    echo "::error::Copilot found no safe code change. Stopping for manual review."
    {
      echo
      echo "## Final result"
      echo
      echo "**NEEDS MANUAL REVIEW** — no evidence-based patch was produced in repair cycle $iteration."
      cat "$HISTORY"
    } >> "$GITHUB_STEP_SUMMARY"
    exit 1
  fi

  while IFS= read -r path; do
    case "$path" in
      lib/*|test/*|android/*|pubspec.yaml|pubspec.lock|analysis_options.yaml|tool/bootstrap_android.sh)
        ;;
      *)
        echo "::error::Copilot changed a disallowed path: $path"
        exit 1
        ;;
    esac
  done <<< "$changed_files"

  if git diff --name-status -- test/ | awk '$1 == "D" { found=1 } END { exit(found ? 0 : 1) }'; then
    echo "::error::A test file was deleted. Refusing to commit this repair."
    exit 1
  fi

  git diff --check
  echo "Patch summary:"
  git diff --stat

  git config user.name "tube-arena-repair-bot"
  git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
  git add -- $changed_files
  git commit -m "fix: repair Android CI failure (AI-assisted cycle $iteration)"

  # The write token is used only after the agent process has exited.
  gh auth setup-git
  git push origin "HEAD:$BRANCH"
  target_sha="$(git rev-parse HEAD)"
  echo "Repair committed and pushed to $BRANCH: $target_sha"

  # The next loop iteration dispatches CI if no exact-SHA run exists.
done
