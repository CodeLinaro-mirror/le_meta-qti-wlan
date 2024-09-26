# allow for local directory containing source to be used

ifeq ($(PKG_NAME),emesh-sp-mcc)
LOCAL_SRC := $(TOPDIR)/src/ipq/emesh-sp
endif

ifeq ($(PKG_NAME),libwpa2-mcc)
LOCAL_SRC := $(TOPDIR)/src/ipq/libwpa2
endif

ifeq ($(PKG_NAME),qca-hyfi-bridge-mcc)
LOCAL_SRC := $(TOPDIR)/src/ipq/qca-hyfi-bridge
endif

LOCAL_SRC ?= $(TOPDIR)/src/wlan/$(PKG_NAME)

ifeq (exists, $(shell [ -d $(LOCAL_SRC) ] && echo exists))
PKG_REV=$(shell cd $(LOCAL_SRC)/; git describe --dirty --long --always --abbrev=7| sed 's/.*-g//g')
PKG_VERSION:=1.0
PKG_SOURCE_URL:=
PKG_UNPACK=mkdir -p $(PKG_BUILD_DIR); $(CP) $(LOCAL_SRC)/* $(PKG_BUILD_DIR)/
endif
