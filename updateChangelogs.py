import requests
import os

f = open("changelogs.txt", "w")
for i in range(1, 10):
    linkAPI = "https://api.github.com/repos/Factorio-Biter-Battles/Factorio-Biter-Battles/pulls?state=closed&per_page=100&"+"page="+str(i)
    #username = ''
    #token = ''
    payload = requests.get(linkAPI).json()
    #payload = requests.get(linkAPI, auth=(username,token)).json()
    
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
                f.write("	table.insert(changelogs_change,\""+formatedLine[2].rstrip("\n").replace('"',"'").replace("Ragnarok77-factorio","Ragnarok77")+"\")\n")
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