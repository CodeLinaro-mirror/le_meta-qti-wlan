include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qcacld-ll
PKG_VERSION:=1.0
PKG_RELEASE:=1
PKG_FIXUP:=autoreconf
PKG_BUILD_DIR :=$(KERNEL_BUILD_DIR)/$(PKG_NAME)-$(BUILD_VARIANT)/
ifeq ($(TARGET_VARIANT),perf)
  COMPILE_MODE :=perf
else
  COMPILE_MODE :=debug
endif

LOCAL_SRC := $(TOPDIR)/src/wlan/qcacld-2.0
EXTRA_ADDR :=lib/modules/$(LINUX_VERSION)-${COMPILE_MODE}/extra
wirelessdir :=$(TOPDIR)/src/external/compat-wireless/net/wireless

include $(INCLUDE_DIR)/package.mk

TARGET_MAKEOPTS := CONFIG_QCA_CLD_WLAN_PROFILE=default

ifeq ($(BOARD),sdx35)
ifeq ($(BUILD_VARIANT),pcie)
TARGET_MAKEOPTS := CONFIG_ARCH_SDXBAAGHA=y \
		   CONFIG_QCA_CLD_WLAN_PROFILE=default \
		   CONFIG_CNSS_OUT_OF_TREE=y \
		   CONFIG_CNSS=y \
		   CONFIG_CNSS_UTILS=m \
		   KERNEL_SUPPORTS_NESTED_COMPOSITES=n \
		   CONFIG_CNSS_OUT_OF_TREE=y \
		   CONFIG_CNSS_CRYPTO=y \
		   CONFIG_CNSS_PCI=y \
		   CONFIG_CNSS_ASYNC=y \
		   CONFIG_CNSS_LOGGER=y \
		   CONFIG_CLD_LL_CORE=y \
		   CONFIG_CNSS_SDIO=n \
		   CONFIG_CLD_HL_SDIO_CORE=n

WLAN_PLATFORM_SYMBOLS = $(PKG_BUILD_DIR)/../wlan-cnss-legacy/Module.symvers
WLAN_CRYPTO_SYMBOLS = $(PKG_BUILD_DIR)/../wlan-cnss-crypto/Module.symvers
TARGET_MAKEOPTS += KBUILD_EXTRA_SYMBOLS="$(WLAN_PLATFORM_SYMBOLS) $(WLAN_CRYPTO_SYMBOLS)"

else ifeq ($(BUILD_VARIANT),sdio)
TARGET_MAKEOPTS := CONFIG_ARCH_SDXBAAGHA=y \
		   CONFIG_QCA_CLD_WLAN_PROFILE=default \
		   CONFIG_CNSS_OUT_OF_TREE=y \
		   CONFIG_CNSS=y \
		   CONFIG_CNSS_UTILS=m \
		   KERNEL_SUPPORTS_NESTED_COMPOSITES=n \
		   CONFIG_CNSS_OUT_OF_TREE=y \
		   CONFIG_CNSS_CRYPTO=y \
		   CONFIG_CNSS_PCI=n \
		   CONFIG_CNSS_SDIO=y \
		   CONFIG_CLD_HL_SDIO_CORE=y \
		   CONFIG_VOS_MEM_PRE_ALLOC=y \
		   MODNAME=wlan_sdio

WLAN_PLATFORM_SYMBOLS = $(PKG_BUILD_DIR)/../wlan-cnss-sdio/Module.symvers
WLAN_CRYPTO_SYMBOLS = $(PKG_BUILD_DIR)/../wlan-cnss-crypto/Module.symvers
TARGET_MAKEOPTS += KBUILD_EXTRA_SYMBOLS="$(WLAN_PLATFORM_SYMBOLS) $(WLAN_CRYPTO_SYMBOLS)"

endif
endif

TARGET_CFLAGS += -DOPENWRT_BUILD

define KernelPackage/$(PKG_NAME)
  SECTION:=Kernel Modules
  CATEGORY:=External Kernel Modules
  TITLE:=WLAN HOST DRIVER
  DEPENDS := +kmod-wlan-cnss-legacy +kmod-wlan-cnss-crypto
  VARIANT:=pcie
endef

define KernelPackage/qcacld-ll-sdio
  SECTION:=Kernel Modules
  CATEGORY:=External Kernel Modules
  TITLE:=WLAN HOST SDIO DRIVER
  DEPENDS := +kmod-wlan-cnss-sdio +kmod-wlan-cnss-crypto
  VARIANT:=sdio
endef

QCACLD_LL_MAKEOPTS=M="$(PKG_BUILD_DIR)/" \
			${TARGET_MAKEOPTS} \
			WLAN_PLATFORM_INC="$(LOCAL_SRC)/../platform/inc"

define  KernelPackage/$(PKG_NAME)/Description
	wlan host driver
endef

define  KernelPackage/qcacld-ll-sdio/Description
	wlan host sdio driver
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)/
	$(CP) $(LOCAL_SRC)/* $(PKG_BUILD_DIR)/
	awk -f ${wirelessdir}/genregdb.awk < ${wirelessdir}/db.txt > $(PKG_BUILD_DIR)/CORE/VOSS/src/vos_regdb.c
endef

define Build/Compile
	$(MAKE) -j32 -C "$(LINUX_DIR)" $(QCACLD_LL_MAKEOPTS)
endef

define Build/InstallDev
	@true
endef

define  KernelPackage/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/$(EXTRA_ADDR)/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/wlan.ko $(1)/$(EXTRA_ADDR)/wlan_rome.ko
	$(INSTALL_DIR) $(TOPDIR)/bin/targets/$(COMPILE_MODE)/modules
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/wlan.ko $(TOPDIR)/bin/targets/$(COMPILE_MODE)/modules/wlan_rome.ko
endef

define  KernelPackage/qcacld-ll-sdio/install
	$(INSTALL_DIR) $(1)/$(EXTRA_ADDR)/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/wlan_prealloc.ko $(1)/$(EXTRA_ADDR)/wlan_prealloc.ko
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/wlan_sdio.ko $(1)/$(EXTRA_ADDR)/wlan_sdio.ko
	$(INSTALL_DIR) $(TOPDIR)/bin/targets/$(COMPILE_MODE)/modules
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/wlan_prealloc.ko $(TOPDIR)/bin/targets/$(COMPILE_MODE)/modules/wlan_prealloc.ko
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/wlan_sdio.ko $(TOPDIR)/bin/targets/$(COMPILE_MODE)/modules/wlan_sdio.ko
endef

$(eval $(call KernelPackage,$(PKG_NAME)))
$(eval $(call KernelPackage,qcacld-ll-sdio))
