include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=wlan-conf
PKG_VERSION:=1.0
PKG_RELEASE:=1
PKG_FIXUP:=autoreconf

LOCAL_SRC := $(TOPDIR)/src/mdm-init

include $(INCLUDE_DIR)/package.mk

TARGET_CFLAGS += -DOPENWRT_BUILD

WLAN_INI_DEFAULT := WCNSS_qcom_cfg.ini
WLAN_INI_PERF := WCNSS_qcom_cfg-perf.ini
WLAN_INI_FILE := $(WLAN_INI_DEFAULT)

ifeq ($(BOARD),sdx65)
	CONFIGURE_ARGS += --enable-target-sdxlemur=yes
	WLAN_SUB_ADDR :=wlan_sdxlemur
else ifeq ($(BOARD),sdx75)
	CONFIGURE_ARGS += --enable-target-sdxpinn=yes
	WLAN_SUB_ADDR :=wlan_sdxpinn
	ifeq ($(TARGET_VARIANT),perf)
		WLAN_INI_FILE := $(WLAN_INI_PERF)
	endif
else ifeq ($(BOARD),sdx35)
	CONFIGURE_ARGS += --enable-target-sdxbaagha=yes
	WLAN_SUB_ADDR :=wlan_sdxbaagha
else
	WLAN_SUB_ADDR :=wlan
endif

CONF_ADDR :=$(PKG_BUILD_DIR)/$(WLAN_SUB_ADDR)
ETC_DATA_ADDR :=/etc/data
MISC_WIFI_ADDR :=/etc/misc/wifi
SYS_CONF_ADDR :=/etc
BASE_LIB_ADDR :=/lib
INIT_D_ADDR :=$(SYS_CONF_ADDR)/init.d
FIRMWARE_ADDR :=$(BASE_LIB_ADDR)/firmware/wlan/qca_cld

define Package/$(PKG_NAME)
  SECTION:=QTI
  CATEGORY:=QTI-PACKAGES
  TITLE:=WLAN CONFIGURE FILES
endef

define Package/$(PKG_NAME)/Description
	wlan config files
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)/
	$(CP) $(LOCAL_SRC)/* $(PKG_BUILD_DIR)/
endef

define Build/InstallDev
	@true
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(STAGING_DIR)
	mkdir -p  $(1)/$(ETC_DATA_ADDR)
	mkdir -p  $(1)/$(MISC_WIFI_ADDR)
	mkdir -p  $(1)/$(INIT_D_ADDR)
	mkdir -p  $(1)/$(FIRMWARE_ADDR)
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/etc/initscripts
	$(CP) $(CONF_ADDR)/cld-hostapd-wlan0.sh $(1)/$(ETC_DATA_ADDR)/
	$(CP) $(CONF_ADDR)/cld-hostapd-wlan1.sh $(1)/$(ETC_DATA_ADDR)/
	$(CP) $(CONF_ADDR)/cld-hostapd-wlan2.sh $(1)/$(ETC_DATA_ADDR)/
	$(CP) $(CONF_ADDR)/hostapd.conf $(1)/$(MISC_WIFI_ADDR)/
	$(CP) $(CONF_ADDR)/hostapd-wlan1.conf $(1)/$(MISC_WIFI_ADDR)/
	$(CP) $(CONF_ADDR)/hostapd-wlan2.conf $(1)/$(MISC_WIFI_ADDR)/
	$(CP) $(CONF_ADDR)/hostapd-wlan3.conf $(1)/$(MISC_WIFI_ADDR)/
	$(CP) $(CONF_ADDR)/sta_mode_hostapd.conf $(1)/$(MISC_WIFI_ADDR)/
	$(CP) $(CONF_ADDR)/wpa_supplicant.conf $(1)/$(MISC_WIFI_ADDR)/
	$(CP) $(CONF_ADDR)/$(WLAN_INI_FILE) $(1)/$(MISC_WIFI_ADDR)/$(WLAN_INI_DEFAULT)
	$(CP) $(CONF_ADDR)/WCNSS_qcom_cfg.Rome.ini $(1)/$(MISC_WIFI_ADDR)/
	$(CP) $(CONF_ADDR)/wlan $(1)/$(INIT_D_ADDR)/
	$(INSTALL_BIN) $(CONF_ADDR)/start_cnss_le.init $(1)/etc/init.d/
	$(INSTALL_BIN) $(CONF_ADDR)/start_cnss_le $(1)/etc/initscripts/
	$(LN) -rsf $(1)/$(MISC_WIFI_ADDR)/$(WLAN_INI_DEFAULT) $(1)/$(FIRMWARE_ADDR)/$(WLAN_INI_DEFAULT)
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
