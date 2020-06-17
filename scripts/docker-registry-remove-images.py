#!/usr/bin/env python

#############################################################################
# NOTICE                                                                    #
#                                                                           #
# This software (or technical data) was produced for the U.S. Government    #
# under contract, and is subject to the Rights in Data-General Clause       #
# 52.227-14, Alt. IV (DEC 2007).                                            #
#                                                                           #
# Copyright 2020 The MITRE Corporation. All Rights Reserved.                #
#############################################################################

#############################################################################
# Copyright 2020 The MITRE Corporation                                      #
#                                                                           #
# Licensed under the Apache License, Version 2.0 (the "License");           #
# you may not use this file except in compliance with the License.          #
# You may obtain a copy of the License at                                   #
#                                                                           #
#    http://www.apache.org/licenses/LICENSE-2.0                             #
#                                                                           #
# Unless required by applicable law or agreed to in writing, software       #
# distributed under the License is distributed don an "AS IS" BASIS,        #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  #
# See the License for the specific language governing permissions and       #
# limitations under the License.                                            #
#############################################################################

# NOTE: This script prioritizes convenience over security.
# 1. "--insecure" is used with curl to skip server certificate validation.

import getpass
import json
import subprocess
import sys

# Enable this to show non-matching repos. All tags in these repos will be kept.
PRINT_REPOS_TO_KEEP = True

# Enable this to show tags that will be kept within matching repos.
PRINT_TAGS_TO_KEEP = True

global registryUrl
global user
global password


def print_usage():
    print "Usages:"
    print "docker-registry-remove-images.py [--dry-run] <registry-url-with-port> <--partial|--exact> -n <image-name>"
    print "docker-registry-remove-images.py [--dry-run] <registry-url-with-port> <--partial|--exact> -t <image-tag>"
    print "docker-registry-remove-images.py [--dry-run] <registry-url-with-port> <--partial|--exact> -n <image-name> -t <image-tag>"
    exit(1)


def do_rest_call(httpMethod, path, parseJson=True):
    process = subprocess.Popen(["curl", "-s", "-S", "--insecure", "-X", httpMethod, "-u", user + ":" + password,
                                registryUrl + "/v2/" + path], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = process.communicate()
    if err:
        raise Exception(err)
    if parseJson:
        data = json.loads(out)
        if "errors" in data:
            raise Exception(data["errors"][0]["code"] + ": " + data["errors"][0]["message"])
        return data


def get_digest(repo, tag):
    process = subprocess.Popen(["curl", "-D", "-", "-s", "-S", "--insecure",
                                "-H", "Accept: application/vnd.docker.distribution.manifest.v2+json",
                                "-u", user + ":" + password, registryUrl + "/v2/" + repo + "/manifests/" + tag,
                                "-o", "/dev/null"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = process.communicate()
    if err:
        raise Exception(err)
    for line in out.splitlines():
        if line.find("Docker-Content-Digest") > -1 and line.find("sha256:") > 1:
            return line.split()[1]
    raise Exception("Cannot get digest")


def get_creation_date(repo, tag):
    data = do_rest_call("GET", repo + "/manifests/" + tag)
    return json.loads(data["history"][0]["v1Compatibility"])["created"][0:10]


dryRun = False
exact = False
nameSearchStr = ""
tagSearchStr = ""

if len(sys.argv) == 8:
    if sys.argv[1] == "--dry-run":
        dryRun = True
    else:
        print_usage()

    registryUrl = sys.argv[2]

    if sys.argv[3] == "--partial":
        exact = False
    elif sys.argv[3] == "--exact":
        exact = True
    else:
        print_usage()

    if sys.argv[4] == "-n":
        nameSearchStr = sys.argv[5]
    else:
        print_usage()

    if sys.argv[6] == "-t":
        tagSearchStr = sys.argv[7]
    else:
        print_usage()

elif len(sys.argv) == 7:
    registryUrl = sys.argv[1]

    if sys.argv[2] == "--partial":
        exact = False
    elif sys.argv[2] == "--exact":
        exact = True
    else:
        print_usage()

    if sys.argv[3] == "-n":
        nameSearchStr = sys.argv[4]
    else:
        print_usage()

    if sys.argv[5] == "-t":
        tagSearchStr = sys.argv[6]
    else:
        print_usage()

elif len(sys.argv) == 6:
    if sys.argv[1] == "--dry-run":
        dryRun = True
    else:
        print_usage()

    registryUrl = sys.argv[2]

    if sys.argv[3] == "--partial":
        exact = False
    elif sys.argv[3] == "--exact":
        exact = True
    else:
        print_usage()

    if sys.argv[4] == "-n":
        nameSearchStr = sys.argv[5]
    elif sys.argv[4] == "-t":
        tagSearchStr = sys.argv[5]
    else:
        print_usage()

elif len(sys.argv) == 5:
    registryUrl = sys.argv[1]

    if sys.argv[2] == "--partial":
        exact = False
    elif sys.argv[2] == "--exact":
        exact = True
    else:
        print_usage()

    if sys.argv[3] == "-n":
        nameSearchStr = sys.argv[4]
    elif sys.argv[3] == "-t":
        tagSearchStr = sys.argv[4]
    else:
        print_usage()

else:
    print_usage()


user = raw_input("Enter registry user: ")
password = getpass.getpass("Entry registry password: ")
print

catalog = do_rest_call("GET", "_catalog")

tagsToRemove = {}

print
print "Image search:"
print

for repo in catalog["repositories"]:
    removeTag = False

    if nameSearchStr:
        if exact and nameSearchStr == repo:
            removeTag = True
        elif not exact and nameSearchStr in repo:
            removeTag = True
        else:
            if not PRINT_REPOS_TO_KEEP:
                continue

    print repo
    try:
        tagList = do_rest_call("GET", repo + "/tags/list")
    except Exception as e:
        print "* [ERROR] " + repo + " (" + str(e) + ")"
        print
        continue   

    if not tagList["tags"]:
        print "* [EMPTY]"
        print
        continue

    if nameSearchStr and not removeTag:
        print "+ [KEEP ALL]"
        print
        continue

    for tag in tagList["tags"]:

        if tagSearchStr:
            if exact and tagSearchStr == tag:
                removeTag = True
            elif not exact and tagSearchStr in tag:
                removeTag = True
            else:
                removeTag = False
                if PRINT_TAGS_TO_KEEP:
                    print "+ [KEEP] " + tag

        if removeTag:
            try:
                digest = get_digest(repo, tag)
                creationDate = get_creation_date(repo, tag)
                if repo not in tagsToRemove:
                    tagsToRemove[repo] = {}
                tagsToRemove[repo][tag] = [digest, creationDate]
                print "- [REMOVE] " + tag
            except Exception as e:
                print "* [ERROR] " + tag + " (" + str(e) + ")"
    print

if not tagsToRemove:
    print
    print "No images found."
    exit(0)

print
if dryRun:  
    print "Found images:"
else:
    print "Removing images:"
print

for repo in tagsToRemove:
    print repo
    maxTagLen = len(max(tagsToRemove[repo], key=len))
    for tag in tagsToRemove[repo]:
        digest, creationDate = tagsToRemove[repo][tag]
        print "- " + tag.ljust(maxTagLen) + "  " + creationDate + "  " + digest[7:19]
        if not dryRun:
            do_rest_call("DELETE", repo + "/manifests/" + digest, False)
    print

print
print "To force garbage collection, run the following command on the registry host:"
print "docker exec -it <registry-container-id> /bin/registry garbage-collect /etc/docker/registry/config.yml"
