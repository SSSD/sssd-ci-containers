#!/usr/bin/python3

import json
import requests
import sys
import os


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


def get_fedora_releases(type, exclude=[], extra=''):
    r = requests.get(f'https://bodhi.fedoraproject.org/releases?state={type}')
    r.raise_for_status()

    versions = [x['version'] for x in r.json()['releases'] if x['id_prefix'] == 'FEDORA']
    versions = list(set(versions) - set(exclude))
    versions.sort()

    return versions


fedora_stable = get_fedora_releases('current')
fedora_devel = get_fedora_releases('pending', exclude=['eln'])

matrix = []
matrix.extend(get_matrix('registry.fedoraproject.org/fedora', fedora_stable, 'fedora-{tag}', 'latest fedora-latest'))
matrix.extend(get_matrix('registry.fedoraproject.org/fedora', fedora_devel, 'fedora-{tag}', 'rawhide'))

if 'action' in sys.argv[1:]:
    with open(os.environ['GITHUB_OUTPUT'], 'a') as f:
        f.write(f'matrix={json.dumps(matrix)}')

print(json.dumps(matrix, indent=2))
