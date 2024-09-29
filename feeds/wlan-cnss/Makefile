include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=wlan-cnss
PKG_VERSION:=1.0
PKG_RELEASE:=1
PKG_FIXUP:=autoreconf
PKG_BUILD_DIR :=$(KERNEL_BUILD_DIR)/$(PKG_NAME)-$(BUILD_VARIANT)/
ifeq ($(BUILD_VARIANT),cnss2)
PKG_BUILD_DIR :=$(KERNEL_BUILD_DIR)/wlan-$(BUILD_VARIANT)/
endif
PKG_LICENSE:=ISC

ifeq ($(TARGET_VARIANT),perf)
  COMPILE_MODE :=perf
else
  COMPILE_MODE :=debug
endif

LOCAL_SRC ?= $(TOPDIR)/src/wlan/platform/
EXTRA_ADDR :=lib/modules/$(LINUX_VERSION)-${COMPILE_MODE}/extra

include $(INCLUDE_DIR)/package.mk

ifeq ($(BOARD),sdx75)
  #Dependency when CONFIG_FEATURE_SMEM_MAILBOX=y
  DATA_SMEM_MODULE := kmod-smem-mailbox
  DATA_SMEM_MAKEOPTS := CONFIG_FEATURE_SMEM_MAILBOX=y

  #Hard-code SMEM module's include folder, when CONFIG_FEATURE_SMEM_MAILBOX=y
  DATA_SMEM_INC := $(TOPDIR)/src/data-kernel/drivers/smem-mailbox/include
  NOSTDINC_FLAGS += -I$(DATA_SMEM_INC)
  DATA_SMEM_MAKEOPTS += NOSTDINC_FLAGS="$(NOSTDINC_FLAGS)"

  #Hard-code SMEM module's PKG NAME & PKG_VERSION, when CONFIG_FEATURE_SMEM_MAILBOX=y
  DATA_SMEM_SYMBOLS = $(PKG_BUILD_DIR)../smem-mailbox-1.0/Module.symvers
  DATA_SMEM_MAKEOPTS += KBUILD_EXTRA_SYMBOLS=$(DATA_SMEM_SYMBOLS)
else ifeq ($(BOARD),sdx85)
  #Dependency when CONFIG_FEATURE_SMEM_MAILBOX=y
  #DATA_SMEM_MODULE := kmod-smem-mailbox
  #DATA_SMEM_MAKEOPTS := CONFIG_FEATURE_SMEM_MAILBOX=y

  #Hard-code SMEM module's include folder, when CONFIG_FEATURE_SMEM_MAILBOX=y
  #DATA_SMEM_INC := $(TOPDIR)/src/data-kernel/drivers/smem-mailbox/include
  #NOSTDINC_FLAGS += -I$(DATA_SMEM_INC)
  #DATA_SMEM_MAKEOPTS += NOSTDINC_FLAGS="$(NOSTDINC_FLAGS)"

  #Hard-code SMEM module's PKG NAME & PKG_VERSION, when CONFIG_FEATURE_SMEM_MAILBOX=y
  #DATA_SMEM_SYMBOLS = $(PKG_BUILD_DIR)../smem-mailbox-1.0/Module.symvers
  #DATA_SMEM_MAKEOPTS += KBUILD_EXTRA_SYMBOLS=$(DATA_SMEM_SYMBOLS)
  DATA_SMEM_MODULE :=
  DATA_SMEM_MAKEOPTS := CONFIG_ARCH_SDXKOVA=y

  #Disable ICNSS on SDXKOVA
  DATA_SMEM_MAKEOPTS += USE_EXTERNAL_CONFIGS=y \
				CONFIG_ARCH_SDXKOVA=y \
				CONFIG_CNSS2=m \
				CONFIG_CNSS2_QMI=y \
				CONFIG_CNSS2_DEBUG=y \
				CONFIG_CNSS_QMI_SVC=m \
				CONFIG_CNSS_PLAT_IPC_QMI_SVC=m \
				CONFIG_CNSS_GENL=m \
				CONFIG_WCNSS_MEM_PRE_ALLOC=m \
				CONFIG_CNSS_UTILS=m \
				CONFIG_CNSS2_SSR_DRIVER_DUMP=y
else
  DATA_SMEM_MODULE :=
  DATA_SMEM_MAKEOPTS :=
endif

define KernelPackage/wlan-cnss2
  SECTION:=Kernel Modules
  CATEGORY:=External Kernel Modules
  TITLE:=CNSS platform driver
  VARIANT:=cnss2
  DEPENDS := +$(DATA_SMEM_MODULE)
endef

define KernelPackage/wlan-cnss-legacy
  SECTION:=Kernel Modules
  CATEGORY:=External Kernel Modules
  TITLE:=CNSS platform driver for legacy
  VARIANT:=legacy
endef

define KernelPackage/wlan-cnss2/Description
	CNSS2 platform driver
endef

define KernelPackage/wlan-cnss-legacy/Description
	CNSS platform driver
endef

ifeq ($(BUILD_VARIANT),cnss2)
CNSS_MAKEOPTS = CONFIG_CNSS_OUT_OF_TREE=y \
		CONFIG_MHI_BUS_MISC=y \
		$(DATA_SMEM_MAKEOPTS) \
		M="$(PKG_BUILD_DIR)"

else ifeq ($(BUILD_VARIANT),legacy)
        CNSS_MAKEOPTS  = CONFIG_CNSS_OUT_OF_TREE=y \
			 M="$(PKG_BUILD_DIR)" \
			 WLAN_PLATFORM_ROOT="$(LOCAL_SRC)" \
			 CONFIG_CNSS=m \
			 CONFIG_CNSS_PCI=y \
			 CONFIG_CNSS_ASYNC=y \
			 CONFIG_CNSS_LOGGER=m \
			 CONFIG_CNSS_CRYPTO=m \
			 CONFIG_CNSS_SHUTDOWN_CALLBACK=y
endif

ifeq ($(BUILD_VARIANT),cnss2)
ifeq ($(BOARD),sdx35)
CNSS_MAKEOPTS = CONFIG_CNSS_OUT_OF_TREE=y \
		CONFIG_MHI_BUS_MISC=y \
		M="$(PKG_BUILD_DIR)" \
		WLAN_PLATFORM_ROOT="$(LOCAL_SRC)" \
		CONFIG_CNSS2=m \
		CONFIG_CNSS2_QMI=y \
		CONFIG_CNSS_QMI_SVC=m \
		CONFIG_CNSS_PLAT_IPC_QMI_SVC=m \
		CONFIG_CNSS_UTILS=m \
		CONFIG_WCNSS_MEM_PRE_ALLOC=m \
		CONFIG_DISABLE_CNSS_SRAM_DUMP=y \
		CONFIG_FREE_M3_BLOB_MEM=y \
		CONFIG_WLAN_MEMORY_OPT=y \
		CONFIG_CNSS_SHUTDOWN_CALLBACK=y
endif
endif

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)/
	$(CP) $(LOCAL_SRC)/* $(PKG_BUILD_DIR)/
endef

define Build/Compile
	$(MAKE) -C "$(LINUX_DIR)" $(CNSS_MAKEOPTS) \
	modules
endef

define Build/InstallDev
	@true
endef

define KernelPackage/wlan-cnss2/install
	$(INSTALL_DIR) $(1)/$(EXTRA_ADDR)/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cnss2/cnss2.ko $(1)/$(EXTRA_ADDR)/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cnss_utils/cnss_utils.ko $(1)/$(EXTRA_ADDR)/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cnss_utils/cnss_plat_ipc_qmi_svc.ko $(1)/$(EXTRA_ADDR)/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cnss_utils/wlan_firmware_service.ko $(1)/$(EXTRA_ADDR)/
ifneq ($(BOARD),sdx35)
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cnss_genl/cnss_nl.ko $(1)/$(EXTRA_ADDR)/
endif
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cnss_prealloc/cnss_prealloc.ko $(1)/$(EXTRA_ADDR)/
	$(INSTALL_DIR) $(TOPDIR)/bin/targets/$(COMPILE_MODE)/modules
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cnss2/cnss2.ko $(TOPDIR)/bin/targets/$(COMPILE_MODE)/modules/
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/etc/initscripts
	$(INSTALL_BIN) ./files/wlan-cnss.init $(1)/etc/init.d/
	$(INSTALL_BIN) ./files/start_wlan_cnss_le $(1)/etc/initscripts/
endef

define KernelPackage/wlan-cnss-legacy/install
	$(INSTALL_DIR) $(1)/$(EXTRA_ADDR)/
	$(INSTALL_DIR) $(TOPDIR)/bin/targets/$(COMPILE_MODE)/modules
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cnss/cnss.ko $(1)/$(EXTRA_ADDR)/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cnss/logger/logger.ko $(1)/$(EXTRA_ADDR)/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cnss_crypto/cnss_crypto.ko $(1)/$(EXTRA_ADDR)/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/cnss/cnss.ko $(TOPDIR)/bin/targets/$(COMPILE_MODE)/modules/
endef

$(eval $(call KernelPackage,wlan-cnss-legacy))
$(eval $(call KernelPackage,wlan-cnss2))
