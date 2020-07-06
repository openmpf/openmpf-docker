#! /usr/bin/env python3

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
# distributed under the License is distributed on an "AS IS" BASIS,         #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  #
# See the License for the specific language governing permissions and       #
# limitations under the License.                                            #
#############################################################################

import os
import sys
import xml.etree.ElementTree


def main():
    reports_dir = sys.argv[1]
    surefire_dir = os.path.join(reports_dir, 'surefire-reports')
    failsafe_dir = os.path.join(reports_dir, 'failsafe-reports')

    all_unsuccessful_tests = process_report_dir(surefire_dir)
    all_unsuccessful_tests += process_report_dir(failsafe_dir)
    if not all_unsuccessful_tests:
        return

    all_unsuccessful_tests.sort()
    print('The following {} tests were unsuccessful:'.format(len(all_unsuccessful_tests)))
    for test in all_unsuccessful_tests:
        print(test)
    sys.exit(1)


def process_report_dir(reports_dir):
    unsuccessful_tests = []
    for path in os.listdir(reports_dir):
        if path.endswith('.xml'):
            full_path = os.path.join(reports_dir, path)
            unsuccessful_tests += process_file(full_path)
    return unsuccessful_tests


def process_file(path):
    tree = xml.etree.ElementTree.parse(path)
    root = tree.getroot()
    if root.tag != 'testsuite':
        return []
    error_count = int(root.attrib['errors'])
    failure_count = int(root.attrib['failures'])
    if error_count == 0 and failure_count == 0:
        return []

    unsuccessful_tests = []
    for test_case in root.findall('testcase'):
        failure = test_case.find('failure')
        error = test_case.find('error')
        if failure is None and error is None:
            continue

        method_name = test_case.attrib['name']
        class_name = test_case.attrib['classname']
        if failure is not None:
            output = failure.text
        else:
            output = error.text
        test_name = '{}.{}'.format(class_name, method_name)
        print('{} failed with error: {}'.format(test_name, output))
        unsuccessful_tests.append(test_name)
    return unsuccessful_tests


if __name__ == '__main__':
    main()
