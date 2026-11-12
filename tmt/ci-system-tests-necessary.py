#!/usr/bin/env python3
"""
Determine if system tests need to be run against a pull request.

This checks if only man pages were edited in a given Pull request diff.

Usage:
  ci-system-tests-necessary.py --repo OWNER/REPO [options]

Options:
  --repo OWNER/REPO  GitHub repository to fetch the pull request diff from.
  --pr ID            Pull request number.       Default: $PACKIT_PR_ID

Examples:
  ci-system-tests-necessary.py --repo SSSD/sssd
  ci-system-tests-necessary.py --repo authselect/authselect
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


def main():
    parser = argparse.ArgumentParser(
        description='Select which tests to run from SELECT_TESTS or a pull request diff.'
    )
    parser.add_argument('--repo', required=True, help='GitHub repository (OWNER/REPO)')
    parser.add_argument('--pr', help='Pull request number (default: $PACKIT_PR_ID)')

    args = parser.parse_args()

    # Use environment variables as defaults
    pr = args.pr or os.environ.get('PACKIT_PR_ID', '')

    if not pr:
        print("Not running against a pull request. System tests run is necessary.")
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

    # Check if man page files only modified
    for patched_file in patch_set:
        if not patched_file.path.startswith("src/man"):
            print(f"System tests run is necessary")
            sys.exit(0)
    print(f"Only man pages edited, system tests run is NOT necessary!")
    sys.exit(1)


if __name__ == '__main__':
    main()
