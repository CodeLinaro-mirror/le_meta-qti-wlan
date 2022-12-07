# Copyright (c) 2022 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

import os
import re
import sys
import shutil

def changeIncludePath(filename):
    pat=re.compile("(#include.<.*/)(Linux)(/.*\.h.*>)")
    dstFile = open('tmp', 'w')
    srcFile = open(filename)
    for line in srcFile.readlines():
        m = pat.match(line)
        if m:
            line = m.group(1) + "qcs610" + m.group(3) + '\n'
        dstFile.write(line)
    dstFile.close()
    os.system("mv -f tmp %s" % filename)

if __name__ == '__main__':
    if len(sys.argv) != 4:
        print("wrong input parameters")
        exit(1)
    curDir  = sys.argv[1]
    patchDir = sys.argv[2]
    srcDir = sys.argv[3]

    exampleGenDir = [os.path.join(curDir, "examples", "all-clusters-app"), os.path.join(curDir, "examples", "platform")]
    for item in exampleGenDir:
        if os.path.exists(os.path.join(item, "qcs610")):
            os.system("rm -rf " + os.path.join(item, "qcs610"))
        if os.path.exists(os.path.join(item, "linux")):
            os.system("cp -r " + os.path.join(item, "linux") + ' ' + os.path.join(item, "qcs610"))

    srcGenDir = os.path.join(curDir, "src", "platform")
    if os.path.exists(os.path.join(srcGenDir, "qcs610")):
        os.system("rm -rf " + os.path.join(srcGenDir, "qcs610"))
    if os.path.exists(os.path.join(srcGenDir, "Linux")):
        shutil.copytree(os.path.join(srcGenDir, "Linux"), os.path.join(srcGenDir, "qcs610"),
                ignore=shutil.ignore_patterns("bluez"))

    if os.path.exists(os.path.join(srcGenDir, "qcs610", "fluoride")):
        os.system("rm -rf " + os.path.join(srcGenDir, "qcs610", "fluoride"))

    os.system("mkdir -p " + os.path.join(srcGenDir, "qcs610", "fluoride"))
    os.system("cp " + os.path.join(srcGenDir, "Linux", "bluez", "Types.h") + ' ' + os.path.join(srcGenDir, "qcs610", "fluoride"))

    changeIncDir = [srcGenDir] + exampleGenDir
    for item in changeIncDir:
        for mainDir, subDir, fileList in os.walk(os.path.join(item, "qcs610")):
            for file in fileList:
                srcFile = os.path.join(mainDir, file)
                changeIncludePath(srcFile)


    # apply patch
    os.chdir(curDir)
    os.system('patch  -p1 < ' + os.path.join(patchDir, 'add-qcs610-in-src-platform-layer.patch'))
    os.system('patch  -p1 < ' + os.path.join(patchDir, 'add-qcs610-in-all-clusters-app-example.patch'))


