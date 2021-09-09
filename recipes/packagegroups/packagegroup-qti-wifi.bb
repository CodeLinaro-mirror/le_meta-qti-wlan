SUMMARY = "QTI WIFI opensource package groups"
LICENSE = "BSD-3-Clause"
PACKAGE_ARCH = "${MACHINE_ARCH}"

inherit packagegroup

PROVIDES = "${PACKAGES}"

PACKAGES = "packagegroup-qti-wifi"

RDEPENDS_packagegroup-qti-wifi = ""
