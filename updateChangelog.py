import json
import requests
import os
import sys

GIT_NAME_MAPPING = {
    "Ragnarok77-factorio": "Ragnarok77",
    "XVhc6A": "DrButtons",
    "amannm": "BigFatDuck",
    "clifffrey": "cliff_build",
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
        'date': sanitize_string(date),
        'title': sanitize_string(pull_req['title']),
        'login': sanitize_string(name)
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

    return requests.get(GH_URL, auth=auth, params=params).json()

def collect_entries():
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

def main():
    print("Usage of script with usage of GitHub token for more API requests: python scriptName username token")
    print("Usage of script without any token: python scriptName")
    print("If the script crashes with a TypeError, it should be because you spammed the GitHub API too much; use a token instead (if the token doesn't work, you failed to give the Python script the correct git username and token)")

    if len(sys.argv) == 1:
        print('No arguments used, will use the default connection to the GitHub API without any token')
    elif len(sys.argv) == 3:
        print('Two arguments provided, will use the token to connect to the API')
    else:
        print('Wrong number of arguments (should be 2 or 0) for the script, will use the default connection to the GitHub API without any token')

    entries = collect_entries()
    with open("maps/biter_battles_v2/changelog_tab.lua", 'r', encoding='utf-8') as log:
        lines = log.readlines()

    source = []
    found_first_line = 0
    for line in lines:
        if "\tadd_entry(" in line and found_first_line == 0:
            found_first_line = 1
            for entry in entries:
                name = entry['login']
                source.append("\tadd_entry(\"" + entry['date'] + "\", \"" + name + "\", \"" + entry['title'] + "\")\n")
        if "\tadd_entry(" not in line:
            source.append(line)

    with open("maps/biter_battles_v2/changelog_tab.lua", 'w', encoding='utf-8') as output:
        output.writelines(source)

if __name__ == '__main__':
    main()
