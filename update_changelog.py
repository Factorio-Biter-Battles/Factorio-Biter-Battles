""" Script for updating in-game changelog tab
"""

import json
import os
import sys
import requests
from luaparser import ast
from luaparser.astnodes import (Table, Chunk, Block, Field, Name,
                                Return, String, Number, StringDelimiter)

GIT_NAME_MAPPING = {
    "DaTa-": "Data-",
    "Ragnarok77-factorio": "Ragnarok77",
    "XVhc6A": "DrButtons",
    "amannm": "BigFatDuck",
    "clifffrey": "cliff_build",
    "developer-8": "developer",
    "outstanding-factorio": "outstanding",
}

def get_name(login):
    """ If possible translate GH login into player handle.
    """
    return GIT_NAME_MAPPING.get(login, login)

def sanitize_string(string):
    """ Simple way of using json to sanitize string for any special characters
    that might break syntax in target lua file.
    """

    return json.dumps(string)[1:-1]

def parse_entry(pull_req):
    """ Process GH pull request metadata
    """

    date = pull_req["merged_at"].split("T")[0]
    name = get_name(pull_req['user']['login'])
    return {
        'number': pull_req['number'],
        'date': sanitize_string(date),
        'comment': sanitize_string(pull_req['title']),
        'author': sanitize_string(name)
    }

def is_valid_entry(pull_req):
    """ Checks if PR should be skipped
    """
    if pull_req["merged_at"] is None:
        return False

    return "[HIDDEN]" not in pull_req['title']

GH_URL = "https://api.github.com/repos/Factorio-Biter-Battles/Factorio-Biter-Battles/pulls"
def fetch_pr_page(auth, page):
    """ Scrape up to 100 PRs per page
    """

    params = {
        'state': 'closed',
        'per_page': 100,
        'page': page,
    }

    resp = requests.get(GH_URL, auth=auth, params=params)
    if resp.status_code == 403 or resp.status_code == 429:
        raise RuntimeError("Rate limit hit @ api.github, try later or use credentials")

    return resp.json()

def gh_collect_entries():
    """ Queries GH pull requests and creates entries out of them for the changelog
    """
    merged_pull_requests = []

    auth = ()
    if len(sys.argv) == 3:
        username = sys.argv[1]
        token = sys.argv[2]
        auth = (username, token)

    for page in range(1, 10):
        payload = fetch_pr_page(auth, page)
        for data in payload:
            if is_valid_entry(data):
                merged_pull_requests.append(data)

    # Sort the merged pull requests by merge date in descending order
    merged_pull_requests.sort(key=lambda x: x["merged_at"], reverse=True)
    entries = []
    for data in merged_pull_requests:
        entries.append(parse_entry(data))

    return entries

def lua_find_table(tree):
    """ Walks through AST to find first Table node.
    """

    for node in ast.walk(tree):
        if isinstance(node, Table):
            break
    return node

def lua_extract_entry(field):
    """ Extracts single entry from Table node entry.
    """

    entry = field.value.fields
    return {
        'number': entry[0].value.n,
        'date': entry[1].value.s,
        'author': entry[2].value.s,
        'comment': entry[3].value.s
    }

class SuppressStdOutput:
    """ Suppresses standard output of noisy modules
    """

    def __init__(self):
        self.prev = None

    def __enter__(self):
        self.prev = sys.stdout
        sys.stdout = open(os.devnull, 'w', encoding='utf-8')

    def __exit__(self, _, __, ___):
        sys.stdout.close()
        sys.stdout = self.prev

def lua_collect_entries():
    """ Go through existing change log and parse entries back to json.
    """

    with open("maps/biter_battles_v2/changes.lua", 'r', encoding='utf-8') as lua:
        src = lua.read()
    with SuppressStdOutput():
        tree = ast.parse(src)
    root = lua_find_table(tree)
    entries = []
    for field in root.fields:
        entries.append(lua_extract_entry(field))
    return entries

def trim_whitespace_unordered_list(string):
    """ Trims whitespaces of a string that contains unordered list entries
    to proper offset.
    e.g.:
    - position 1
    - position 2
    ...
    """

    new = []
    for line in string.splitlines():
        candidate = line.lstrip()
        if candidate and candidate[0] == '-':
            line = '  ' + candidate
        new += line + '\n'
    return ''.join(new)

def lua_dump_entries(entries):
    """ Convert json entries back into lua entries.
    """

    fields = []
    for entry in entries:
        _fields = [
            Field(Name('number'), Number(entry['number'])),
            Field(Name('date'), String(entry['date'], StringDelimiter.SINGLE_QUOTE)),
            Field(Name('author'), String(entry['author'], StringDelimiter.SINGLE_QUOTE)),
            Field(Name('comment'), String(entry['comment'], StringDelimiter.DOUBLE_SQUARE)),
        ]
        fields.append(Table(_fields))

    exp = Chunk(Block([
        Return([Table(fields=fields)]),
    ]))

    src = ast.to_lua_source(exp)
    src = trim_whitespace_unordered_list(src)
    with open("maps/biter_battles_v2/changes.lua", 'w', encoding='utf-8') as lua:
        lua.write(src)

def gh_filter_unique_pulls(entries, pulls):
    """ Goes through all available PRs and outputs new/fresh ones that shall
    be added to changelog.
    """

    old = [entry['number'] for entry in entries]
    new = []
    for pull in pulls:
        if pull['number'] in old:
            continue
        new.append(pull)

    return new

def gh_tag_pulls(pulls):
    """ Tag new entries with PR number for reference
    """

    for pull in pulls:
        pull['comment'] = f"(#{pull['number']}) {pull['comment']}"

def main():
    print("Usage of script with usage of GitHub token for more API requests: python scriptName username token")
    print("Usage of script without any token: python scriptName")

    if len(sys.argv) == 1:
        print('No arguments used, will use the default connection to the GitHub API without any token')
    elif len(sys.argv) == 3:
        print('Two arguments provided, will use the token to connect to the API')
    else:
        print('Wrong number of arguments (should be 2 or 0) for the script, will use the default connection to the GitHub API without any token')

    pulls = gh_collect_entries()
    entries = lua_collect_entries()
    new = gh_filter_unique_pulls(entries, pulls)
    gh_tag_pulls(new)
    lua_dump_entries(new + entries)

if __name__ == '__main__':
    main()
