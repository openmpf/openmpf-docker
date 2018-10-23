#!/usr/bin/python

#############################################################################
# NOTICE                                                                    #
#                                                                           #
# This software (or technical data) was produced for the U.S. Government    #
# under contract, and is subject to the Rights in Data-General Clause       #
# 52.227-14, Alt. IV (DEC 2007).                                            #
#                                                                           #
# Copyright 2018 The MITRE Corporation. All Rights Reserved.                #
#############################################################################

#############################################################################
# Copyright 2018 The MITRE Corporation                                      #
#                                                                           #
# Licensed under the Apache License, Version 2.0 (the "License");           #
# you may not use this file except in compliance with the License.          #
# You may obtain a copy of the License at                                   #
#                                                                           #
#    http://www.apache.org/licenses/LICENSE-2.0                             #
#                                                                           #
# Unless required by applicable law or agreed to in writing, software       #
# distributed under the License is distributed don an "AS IS" BASIS,         #
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

global registryUrl
global user
global password


def print_usage():
    print "Usages:"
    print "docker-registry-remove-images.py [--dry-run] <registry-url-with-port> -t <partial-image-tag>"
    print "docker-registry-remove-images.py [--dry-run] <registry-url-with-port> -n <partial-image-name>"
    exit(1)


def do_rest_call(httpMethod, path):
    process = subprocess.Popen(["curl", "-s", "-S", "--insecure", "-X", httpMethod, "-u", user + ":" + password,
                                registryUrl + "/v2/" + path], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = process.communicate()
    if err:
        raise Exception(err)
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
        if line.find("Docker-Content-Digest") > -1:
            return line.split()[1]
    raise Exception("Cannot get digest for " + repo + ":" + tag + ".")


dryRun = False

if len(sys.argv) == 5:
    if sys.argv[1] == "--dry-run":
        dryRun = True
    else:
        print_usage()
elif len(sys.argv) != 4:
    print_usage()

registryUrl = sys.argv[len(sys.argv)-3]
mode = sys.argv[len(sys.argv)-2]
searchStr = sys.argv[len(sys.argv)-1]

user = raw_input("Enter registry user: ")
password = getpass.getpass("Entry registry password: ")
print

catalog = do_rest_call("GET", "_catalog")

tagsToRemove = {}

print "Images to remove:"
print

removeTag = False
for repo in catalog["repositories"]:
    print repo

    if mode == "-n":
        if searchStr in repo:
            removeTag = True
        else:
            print "+ [KEEP ALL]"
            print
            continue

    tagList = do_rest_call("GET", repo + "/tags/list")
    for tag in tagList["tags"]:

        if mode == "-t":
            if searchStr in tag:
                removeTag = True
            else:
                print "+ [KEEP] " + tag

        if removeTag:
            if repo not in tagsToRemove:
                tagsToRemove[repo] = {}
            tagsToRemove[repo][tag] = get_digest(repo, tag)
            print "- [REMOVE] " + tag
    print

print
if not tagsToRemove:
    print "No images found."
    exit(0)

if not dryRun:
    print "Removing images:"
    print

    for repo in tagsToRemove:
        print repo
        for tag in tagsToRemove[repo]:
            digest = tagsToRemove[repo][tag]
            print "Removing " + digest
        print
