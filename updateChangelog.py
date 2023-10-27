import requests
import os
import sys

f = open("changelog.txt", "w")

gitNameToFactorioUsername = {
    "Ragnarok77-factorio": "Ragnarok77",
    "XVhc6A": "DrButtons",
}

print("Usage of script with usage of GitHub token for more API requests: python scriptName username token")
print("Usage of script without any token: python scriptName")
print("If the script crashes with a TypeError, it should be because you spammed the GitHub API too much; use a token instead (if the token doesn't work, you failed to give the Python script the correct git username and token)")

if len(sys.argv) == 1:
    print('No arguments used, will use the default connection to the GitHub API without any token')
elif len(sys.argv) == 3:
    print('Two arguments provided, will use the token to connect to the API')
else:
    print('Wrong number of arguments (should be 2 or 0) for the script, will use the default connection to the GitHub API without any token')

merged_pull_requests = []

for i in range(1, 10):
    payload = None
    linkAPI = "https://api.github.com/repos/Factorio-Biter-Battles/Factorio-Biter-Battles/pulls?state=closed&per_page=100&" + "page=" + str(i)
    if len(sys.argv) == 3:
        username = sys.argv[1]
        token = sys.argv[2]
        payload = requests.get(linkAPI, auth=(username, token)).json()
    else:
        payload = requests.get(linkAPI).json()

    for data in payload:
        mergedAt = data["merged_at"]
        if mergedAt is not None:
            merged_pull_requests.append(data)

# Sort the merged pull requests by merge date in descending order
merged_pull_requests.sort(key=lambda x: x["merged_at"], reverse=True)

for data in merged_pull_requests:
    dateUpdate = data["merged_at"].split("T")[0]
    f.write(f'{dateUpdate};{data["title"]};{data["user"]["login"]}' + "\n")

f.close()

fchangelogTab = open("maps/biter_battles_v2/changelog_tab.lua", "r")
lines = fchangelogTab.readlines()
fchangelogTab.close()

f = open("maps/biter_battles_v2/changelog_tab_temp.lua", "w")
foundFirstLine = 0
for line in lines:
    if "table.insert(changelog_change" in line and foundFirstLine == 0:
        foundFirstLine = 1
        fnewlogs = open("changelog.txt", "r")
        linesnewLogs = fnewlogs.readlines()
        fnewlogs.close()
        for lineNew in linesnewLogs:
            formatedLine = lineNew.split(";")
            if "[HIDDEN]" not in formatedLine[1]:
                f.write("	table.insert(changelog_change,\"" + formatedLine[0].rstrip("\n").replace('"', "'") + "\")\n")
                f.write("	table.insert(changelog_change,\"" + formatedLine[1].rstrip("\n").replace('"', "'") + "\")\n")
                cleanedName = formatedLine[2].rstrip("\n").replace('"', "'")
                if cleanedName in gitNameToFactorioUsername:
                    cleanedName = gitNameToFactorioUsername[cleanedName]
                f.write("	table.insert(changelog_change,\"" + cleanedName + "\")\n")
    if "table.insert(changelog_change" not in line:
        f.write(line)
f.close()





fa = open("maps/biter_battles_v2/changelog_tab_temp.lua", "r")
fb = open("maps/biter_battles_v2/changelog_tab.lua", "w")
lines = fa.readlines()
for line in lines:
    fb.write(line)
fa.close()
fb.close()

os.remove("maps/biter_battles_v2/changelog_tab_temp.lua") 
os.remove("changelog.txt") 