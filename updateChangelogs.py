import requests
import os
import sys

f = open("changelogs.txt", "w")

#Dictionary used if a dev wants to change the gitusername  to their factorio username
#Left : Git username // Right : Factorio username
gitNameToFactorioUsername =	{
  "Ragnarok77-factorio": "Ragnarok77",
}

print("Usage of script with usage of github token for more api requests : python scriptName username token")
print("Usage of script without any token : python scriptName")
print("If the script crashes with typerror, it should be because you spammed api of github too much, use token instead (if token doesn't work, you failed to give the python script correct git username and token")

if len(sys.argv) == 1:
    print ('no argument used, will use default connection to github api without any token')
elif len(sys.argv) == 3:
    print ('2 arguments provided, will use the token to connect to api')
else:
    print('Wrong number of arguments (should be 2 or 0) for script, will use default connection to github api without any token')
        
for i in range(1, 10):
    payload = None
    linkAPI = "https://api.github.com/repos/Factorio-Biter-Battles/Factorio-Biter-Battles/pulls?state=closed&per_page=100&"+"page="+str(i)
    if len(sys.argv) == 3:
        username = sys.argv[1]
        token = sys.argv[2]
        payload = requests.get(linkAPI,auth=(username,token)).json()
    else:
        payload = requests.get(linkAPI).json()
        
    for data in payload:
        mergedAt = data["merged_at"]
        if mergedAt is not None:
            dateUpdate = data["merged_at"].split("T")[0]
            f.write(f'{dateUpdate};{data["title"]};{data["user"]["login"]}'+"\n") 
f.close()




fChangelogsTab = open("maps/biter_battles_v2/changelogs_tab.lua", "r")
lines = fChangelogsTab.readlines()
fChangelogsTab.close()

f = open("maps/biter_battles_v2/changelogs_tab_temp.lua", "w")
foundFirstLine=0
for line in lines:
    if "table.insert(changelogs_change" in line and foundFirstLine == 0:
        foundFirstLine=1
        fnewlogs = open("changelogs.txt", "r")
        linesnewLogs = fnewlogs.readlines()
        fnewlogs.close()
        for lineNew in linesnewLogs:
            formatedLine=lineNew.split(";")
            if "[HIDDEN]" not in formatedLine[1]:
                f.write("	table.insert(changelogs_change,\""+formatedLine[0].rstrip("\n").replace('"',"'")+"\")\n")
                f.write("	table.insert(changelogs_change,\""+formatedLine[1].rstrip("\n").replace('"',"'")+"\")\n")
                
                cleanedName = formatedLine[2].rstrip("\n").replace('"',"'")
                if cleanedName in gitNameToFactorioUsername:
                    cleanedName=gitNameToFactorioUsername[cleanedName]
                f.write("	table.insert(changelogs_change,\""+cleanedName+"\")\n")
    if "table.insert(changelogs_change" not in line:
        f.write(line)
f.close()




fa = open("maps/biter_battles_v2/changelogs_tab_temp.lua", "r")
fb = open("maps/biter_battles_v2/changelogs_tab.lua", "w")
lines = fa.readlines()
for line in lines:
    fb.write(line)
fa.close()
fb.close()

os.remove("maps/biter_battles_v2/changelogs_tab_temp.lua") 
os.remove("changelogs.txt") 