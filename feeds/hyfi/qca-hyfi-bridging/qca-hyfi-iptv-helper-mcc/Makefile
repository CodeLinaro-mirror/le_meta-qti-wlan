include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-hyfi-iptv-helper-mcc
PKG_RELEASE:=1

include $(TOPDIR)/owrt-qti-wlan/include/local-development.mk
ifeq ($(DUMP)$(PKG_VERSION),)
  PKG_REV:=$(shell git ls-remote $(PKG_SOURCE_URL) $(PKG_BRANCH) | cut -b -7)
  PKG_VERSION:=g$(PKG_REV)
endif
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

WIFI_PINNACLE:=PACKAGE_kmod-qcacld32-ll
WIFI_PKGS:=$(WIFI_PINNACLE)
PKG_BUILD_DEPENDS:=$(WIFI_PINNACLE):qcacld32-ll

QCAHYFI_IPTV_HELPER_MAKE_OPTS:= \
        CROSS_COMPILE=$(KERNEL_CROSS) \
        ARCH=$(LINUX_KARCH) \
        KERNELPATH=$(LINUX_SRC_DIR) \
        KBUILDPATH=$(LINUX_DIR) \
        KERNELRELEASE=$(LINUX_RELEASE)

include $(INCLUDE_DIR)/package.mk

QTI_SOFTWARE_CATEGORY:=QTI software

QCAHYBRID_MODULE_LIST:=$(PKG_BUILD_DIR)/hyfi-iptv-helper.ko

define KernelPackage/qca-hyfi-iptv-helper-mcc
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  URL:=http://www.qca.qualcomm.com
  MAINTAINER:=Qualcomm Atheros, Inc.
  TITLE:=IPTV on Wireless Interface Netfilter Module
  DEPENDS:=@$(WIFI_PKGS)
  KCONFIG:= \
    CONFIG_NETFILTER=y \
    CONFIG_BRIDGE_NETFILTER=y
  FILES:= $(strip $(QCAHYBRID_MODULE_LIST))
  SUBMENU:=Hy-Fi features
endef

define KernelPackage/qca-hyfi-iptv-helper-mcc/description
  This package installs the QCA Hy-Fi Netfilter for IPTV implementations on Wireless interface
endef

define Build/Compile
	$(MAKE) -C $(LINUX_DIR) M=$(PKG_BUILD_DIR) $(strip $(QCAHYFI_IPTV_HELPER_MAKE_OPTS))
endef

$(eval $(call KernelPackage,qca-hyfi-iptv-helper-mcc))
