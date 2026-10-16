#!/usr/bin/python3

import json
import os
import sys

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

BODHI_RELEASES_URL = 'https://bodhi.fedoraproject.org/releases'
# Bodhi sometimes drops idle connections; retry transient failures.
REQUEST_TIMEOUT = (5, 30)
MAX_RETRIES = 4
RETRY_BACKOFF = 1.5


def _bodhi_session():
    """HTTP session with retries for Bodhi flakiness."""
    session = requests.Session()
    retry = Retry(
        total=MAX_RETRIES,
        connect=MAX_RETRIES,
        read=MAX_RETRIES,
        status=MAX_RETRIES,
        backoff_factor=RETRY_BACKOFF,
        status_forcelist=(429, 500, 502, 503, 504),
        allowed_methods=frozenset(['GET']),
        raise_on_status=False,
    )
    session.mount('https://', HTTPAdapter(max_retries=retry))
    return session


def get_matrix(image, image_tags, ci_tag, ci_tag_extra):
    def is_last(tag):
        """ Return true if this is the last tag in the set. """
        return tag == image_tags[-1]

    matrix = []
    for tag in image_tags:
        matrix.append({
            'base': f'{image}:{tag}-x86_64',
            'tag': ci_tag.format(tag=tag),
            'extra': ci_tag_extra if is_last(tag) else ''
        })

    return matrix


def get_fedora_releases(type, exclude=None, extra=''):
    if exclude is None:
        exclude = []

    session = _bodhi_session()
    r = session.get(
        BODHI_RELEASES_URL,
        params={'state': type},
        timeout=REQUEST_TIMEOUT,
    )
    r.raise_for_status()

    versions = [x['version'] for x in r.json()['releases'] if x['id_prefix'] == 'FEDORA']
    versions = list(set(versions) - set(exclude))
    versions.sort()

    return versions


fedora_stable = get_fedora_releases(['current', 'frozen'])
fedora_devel = get_fedora_releases(['pending'], exclude=['eln'])

matrix = []
matrix.extend(get_matrix('registry.fedoraproject.org/fedora', fedora_stable, 'fedora-{tag}', 'latest fedora-latest'))
matrix.extend(get_matrix('registry.fedoraproject.org/fedora', fedora_devel, 'fedora-{tag}', 'rawhide'))

if 'action' in sys.argv[1:]:
    with open(os.environ['GITHUB_OUTPUT'], 'a') as f:
        f.write(f'matrix={json.dumps(matrix)}')

print(json.dumps(matrix, indent=2))
