# Copyright (c) 2022 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

import sys
import os
import re

if __name__ == "__main__":
    fileName = sys.argv[1]
    dirName = sys.argv[2].replace('/', '_')
    outString = ''
    pat = re.compile(f"(\s+rspfile = __third_party_connectedhomeip_src_\w+){dirName}(_build_toolchain_custom_custom__rule.rsp)")
    for eachLine in open(fileName):
        m = pat.match(eachLine)
        if m:
            outString += (m.group(1) + m.group(2)+ os.linesep)
        else:
            if "--module pip -- install" in eachLine:
                eachLine = eachLine.rstrip() + " --target pip_pkg" + os.linesep
            outString += eachLine
    outFile = open(fileName, 'w')
    outFile.write(outString)

