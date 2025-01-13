import requests
import os
import sys

GIT_NAME_MAPPING = {
    "Ragnarok77-factorio": "Ragnarok77",
    "XVhc6A": "DrButtons",
    "amannm": "BigFatDuck",
    "clifffrey": "cliff_build",
}

def collect_entries():
    """ Queries GH pull requests and creates entries out of them for the changelog
    """
    merged_pull_requests = []

    for i in range(1, 10):
        payload = None
        link_api = "https://api.github.com/repos/Factorio-Biter-Battles/Factorio-Biter-Battles/pulls?state=closed&per_page=100&" + "page=" + str(i)
        if len(sys.argv) == 3:
            username = sys.argv[1]
            token = sys.argv[2]
            payload = requests.get(link_api, auth=(username, token)).json()
        else:
            payload = requests.get(link_api).json()

        for data in payload:
            merged_at = data["merged_at"]
            if merged_at is not None:
                merged_pull_requests.append(data)

    # Sort the merged pull requests by merge date in descending order
    merged_pull_requests.sort(key=lambda x: x["merged_at"], reverse=True)
    entries = []
    for data in merged_pull_requests:
        date_update = data["merged_at"].split("T")[0]
        entries.append(f'{date_update};{data["title"]};{data["user"]["login"]}' + "\n")

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

    f = open("maps/biter_battles_v2/changelog_tab_temp.lua", "w")
    found_first_line = 0
    for line in lines:
        if "\tadd_entry(" in line and found_first_line == 0:
            found_first_line = 1
            for line_new in entries:
                formated_line = line_new.split(";")
                if "[HIDDEN]" not in formated_line[1]:
                    cleaned_name = formated_line[2].rstrip("\n").replace('"', "'")
                    if cleaned_name in GIT_NAME_MAPPING:
                        cleaned_name = GIT_NAME_MAPPING[cleaned_name]
                    f.write("\tadd_entry(\"" + formated_line[0].rstrip("\n").replace('"', "'") + "\", \"" +
                            cleaned_name + "\", \"" + formated_line[1].rstrip("\n").replace('"', "'") + "\")\n")
        if "\tadd_entry(" not in line:
            f.write(line)
    f.close()

    with open("maps/biter_battles_v2/changelog_tab_temp.lua", 'r', encoding='utf-8') as tmp:
        lines = tmp.readlines()

    with open("maps/biter_battles_v2/changelog_tab.lua", 'w', encoding='utf-8') as output:
        output.writelines(lines)

    os.remove("maps/biter_battles_v2/changelog_tab_temp.lua") 

if __name__ == '__main__':
    main()
