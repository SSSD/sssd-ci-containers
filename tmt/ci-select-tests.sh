#!/usr/bin/env bash
#
# Select which tests to run based on a pull request's diff.
#
# Inspects the diff of a GitHub pull request and decides whether the change
# is test-only. If so, it writes a pytest -k filter expression naming only the
# tests that were added or modified into an env file; the caller is expected
# to pass it as -k "$SELECT_TESTS" when running pytest. When the change is not
# test-only (or there is no pull request), nothing is written, meaning the
# caller should run the full test suite.
#
# Usage:
#   ci-select-tests.sh --repo OWNER/REPO [options]
#
# Options:
#   --repo OWNER/REPO  GitHub repository to fetch the pull request diff from.
#   --pr ID            Pull request number.       Default: $PACKIT_PR_ID
#   --test-dir DIR     Repo-relative directory holding the tests, used to
#                       decide whether a change is test-only.
#                                                  Default: src/tests/system/tests
#   --env-file FILE    File to write SELECT_TESTS into.
#                                                  Default: $TMT_PLAN_ENVIRONMENT_FILE
#
# Examples:
#   ci-select-tests.sh --repo SSSD/sssd
#   ci-select-tests.sh --repo authselect/authselect --test-dir tests/system
#

set -e -o pipefail

repo=""
pr="${PACKIT_PR_ID:-}"
test_dir="src/tests/system/tests"
env_file="${TMT_PLAN_ENVIRONMENT_FILE:-}"

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --repo)     repo="$2";     shift 2 ;;
        --pr)       pr="$2";       shift 2 ;;
        --test-dir) test_dir="$2"; shift 2 ;;
        --env-file) env_file="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$repo" ]]; then
    echo "ERROR: No repository given, use --repo OWNER/REPO." >&2
    exit 1
fi

if [[ -z "$env_file" ]]; then
    echo "ERROR: No env file given, use --env-file or set TMT_PLAN_ENVIRONMENT_FILE." >&2
    exit 1
fi

if [[ -z "$pr" ]]; then
    echo "Not running against a pull request. Will run all tests."
    exit 0
fi

echo "Fetching diff for pull request $repo#$pr..."

# Use retry to avoid github rate limiting, curl will use exponential back-off.
# -S keeps curl's own error message visible even though -s silences the
# progress meter, so a failed fetch explains itself in the logs.
DIFF=$(curl -sSfL --retry 10 --retry-all-errors --retry-max-time 60 "https://github.com/$repo/pull/$pr.diff")

echo "Pull request $repo#$pr has ($(echo "$DIFF" | wc -l) lines)."

FILES=$(echo "$DIFF" | grep -E '^diff --git' | sed -E 's|^diff --git a/(.*) b/.*|\1|')

# Find if any non-test function was modified, in that case we need to
# run all tests as we do not know where the function is used
if echo "$FILES" | grep -qvF "$test_dir"; then
    echo "Non-test files were changed. Will run all tests."
    exit 0
elif echo "$DIFF" | grep -qP '^(@@.+|\+|-)\s*def (?!test_)'; then
    echo "Non-test function was modified. Will run all tests."
    exit 0
fi

# Find all tests that were added. The `|| true` keeps an empty match (no
# added tests) from aborting the script under `set -e -o pipefail`.
ADDED=$(echo "$DIFF" | grep -P "^\+\s*def test_" | sed -E 's/.+def (test_[^(]+).+/\1/' || true)

# Find all tests that are used as tokens in diff. Same `|| true` reasoning.
MODIFIED=$(echo "$DIFF" | grep -E "^@@.+def test_" | sed -E 's/.+def (test_[^(]+).+/\1/' || true)

# Combine and sort
TESTS=$(echo -e "$ADDED\n$MODIFIED" | sort | uniq)

echo "Following tests were added or modified (or token is present in diff):"
echo "$TESTS"

# Store only the -k expression. The caller passes it as -k "$SELECT_TESTS" so
# an empty value (unset here) makes pytest run all tests. Do not embed the -k
# flag or quotes: this crosses to the test as a runtime env var, which the
# shell does not re-parse (unlike GitHub Actions text substitution).
if [[ -n "$TESTS" ]]; then
    FILTER=$(echo "$TESTS" | xargs | sed 's/ / or /g')
    echo "SELECT_TESTS=$FILTER" >> "$env_file"
    echo "Set SELECT_TESTS in env file:"
    grep SELECT_TESTS "$env_file"
fi
