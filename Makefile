GO_EASY_ON_ME = 1
DEBUG = 0
TARGET = iphone:latest:9.0
PACKAGE_VERSION = 1.0-4

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = UnlimShortcut
UnlimShortcut_FILES = Tweak.xm

include $(THEOS_MAKE_PATH)/tweak.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp -R Resources $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/UnlimShortcut$(ECHO_END)
	$(ECHO_NOTHING)find $(THEOS_STAGING_DIR) -name .DS_Store | xargs rm -rf$(ECHO_END)