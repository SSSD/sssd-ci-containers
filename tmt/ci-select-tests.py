#!/usr/bin/env python3
"""
Select which tests to run from SELECT_TESTS or a pull request's diff.

Uses SELECT_TESTS if nonempty; otherwise inspects the diff of a GitHub pull
request and decides whether the change is test-only. If so, it writes a
pytest -k filter expression naming only the tests that were added or modified
into an env file as SELECTED_TESTS; the caller is expected to pass it as
-k "${SELECTED_TESTS:-}" when running pytest. When the change is not test-only
(or there is no pull request), nothing is written, meaning the caller should
run the full test suite.

Keep SELECTED_TESTS out of the plan's initial environment so inline scripts
expand it at runtime, after the tests have been selected.
Value of SELECTED_TESTS should be quoted: tmt reads this env file with shlex.split(),
re-tokenizing on whitespace. A bare "a or b" would be split into the
tokens "a", "or", "b"; the ones without "=" then make tmt fail with
"Failed to extract variables from 'dotenv' format." The quotes are
consumed by shlex, so tmt stores the value without them.

Usage:
  ci-select-tests.py --repo OWNER/REPO [options]

Options:
  --repo OWNER/REPO  GitHub repository to fetch the pull request diff from.
  --pr ID            Pull request number.       Default: $PACKIT_PR_ID
  --test-dir DIR     Repo-relative directory holding the tests, used to
                      decide whether a change is test-only.
                                                 Default: src/tests/system/tests
  --env-file FILE    File to write SELECTED_TESTS into.
                                                 Default: $TMT_PLAN_ENVIRONMENT_FILE

Examples:
  ci-select-tests.py --repo SSSD/sssd
  ci-select-tests.py --repo authselect/authselect --test-dir tests/system
"""

import argparse
import os
import re
import sys
import time
import urllib.request
import urllib.error
from typing import Set
from unidiff import PatchSet


def fetch_pr_diff(repo: str, pr: str) -> str:
    """Fetch the diff for a GitHub pull request with retry logic."""
    url = f"https://github.com/{repo}/pull/{pr}.diff"

    max_retries = 10
    retry_count = 0

    while retry_count <= max_retries:
        try:
            request = urllib.request.Request(url)
            with urllib.request.urlopen(request, timeout=60) as response:
                return response.read().decode('utf-8')
        except (urllib.error.URLError, urllib.error.HTTPError, OSError) as e:
            retry_count += 1
            if retry_count > max_retries:
                raise RuntimeError(f"Failed to fetch diff after {max_retries} retries: {e}")
            # Exponential backoff
            wait_time = min(2 ** retry_count, 60)
            print(f"Retry {retry_count}/{max_retries} after {wait_time}s...", file=sys.stderr)
            time.sleep(wait_time)


def is_non_test_file_modified(patch_set: PatchSet, test_dir: str) -> bool:
    """Check if any non-test files were modified."""
    for patched_file in patch_set:
        # Check if the file path is outside the test directory
        if not patched_file.path.startswith(test_dir):
            return True
    return False


def has_non_test_function(patch_set: PatchSet) -> bool:
    """Check if any non-test function definitions were added, removed, or modified."""
    # Pattern to match function definitions that don't start with test_
    # Matches: def <name> but NOT def test_<name>
    non_test_func_pattern = re.compile(r'^\s*def\s+(?!test_)\w+')

    for patched_file in patch_set:
        for hunk in patched_file:
            # Check hunk header (@@) for function context
            if hunk.section_header and non_test_func_pattern.search(hunk.section_header):
                return True

            # Check added and removed lines
            for line in hunk:
                if line.is_added or line.is_removed:
                    if non_test_func_pattern.match(line.value):
                        return True

    return False


def extract_test_names(patch_set: PatchSet) -> Set[str]:
    """Extract names of added or modified test functions."""
    test_pattern = re.compile(r'def\s+(test_\w+)')
    added_tests = set()
    modified_tests = set()

    for patched_file in patch_set:
        for hunk in patched_file:
            # Find tests in added lines
            for line in hunk:
                if line.is_added:
                    match = test_pattern.search(line.value)
                    if match:
                        added_tests.add(match.group(1))

            # Find tests in hunk header (indicates modified context)
            if hunk.section_header:
                match = test_pattern.search(hunk.section_header)
                if match:
                    modified_tests.add(match.group(1))

    return added_tests | modified_tests


def main():
    parser = argparse.ArgumentParser(
        description='Select which tests to run from SELECT_TESTS or a pull request diff.'
    )
    parser.add_argument('--repo', required=True, help='GitHub repository (OWNER/REPO)')
    parser.add_argument('--pr', help='Pull request number (default: $PACKIT_PR_ID)')
    parser.add_argument('--test-dir', default='src/tests/system/tests',
                        help='Repo-relative directory holding tests')
    parser.add_argument('--env-file', help='File to write SELECTED_TESTS into (default: $TMT_PLAN_ENVIRONMENT_FILE)')

    args = parser.parse_args()

    # Use environment variables as defaults
    pr = args.pr or os.environ.get('PACKIT_PR_ID', '')
    env_file = args.env_file or os.environ.get('TMT_PLAN_ENVIRONMENT_FILE', '')

    if not env_file:
        print("ERROR: No env file given, use --env-file or set TMT_PLAN_ENVIRONMENT_FILE.", file=sys.stderr)
        sys.exit(1)

    # If SELECT_TESTS is already set, use it
    select_tests = os.environ.get('SELECT_TESTS', '')
    if select_tests:
        with open(env_file, 'a') as f:
            f.write(f'SELECTED_TESTS="{select_tests}"\n')
        print("Set SELECTED_TESTS from SELECT_TESTS in env file:")
        with open(env_file, 'r') as f:
            for line in f:
                if line.startswith('SELECTED_TESTS='):
                    print(line.rstrip())
        sys.exit(0)

    if not pr:
        print("Not running against a pull request. Will run all tests.")
        sys.exit(0)

    print(f"Fetching diff for pull request {args.repo}#{pr}...")

    try:
        diff_content = fetch_pr_diff(args.repo, pr)
    except Exception as e:
        print(f"ERROR: Failed to fetch diff: {e}", file=sys.stderr)
        sys.exit(1)

    line_count = len(diff_content.splitlines())
    print(f"Pull request {args.repo}#{pr} has ({line_count} lines).")

    # Parse the diff using unidiff
    patch_set = PatchSet(diff_content)

    # Check if non-test files were modified
    if is_non_test_file_modified(patch_set, args.test_dir):
        print("Non-test files were changed. Will run all tests.")
        sys.exit(0)

    # Check if non-test functions were modified
    if has_non_test_function(patch_set):
        print("Non-test function was modified. Will run all tests.")
        sys.exit(0)

    # Extract test names
    tests = extract_test_names(patch_set)

    if tests:
        print("Following tests were added or modified (or token is present in diff):")
        for test in sorted(tests):
            print(test)

        # Create pytest -k filter expression
        filter_expr = ' or '.join(sorted(tests))
        with open(env_file, 'a') as f:
            f.write(f'SELECTED_TESTS="{filter_expr}"\n')

        print("Set SELECTED_TESTS in env file:")
        with open(env_file, 'r') as f:
            for line in f:
                if line.startswith('SELECTED_TESTS='):
                    print(line.rstrip())


if __name__ == '__main__':
    main()
