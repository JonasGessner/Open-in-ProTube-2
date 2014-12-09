ARCHS = armv7 armv7s arm64

TARGET = iphone:clang:latest:5.0

THEOS_BUILD_DIR = Packages

include theos/makefiles/common.mk

TWEAK_NAME = OpeninProTube2
OpeninProTube2_CFLAGS = -fobjc-arc
OpeninProTube2_FILES = OpeninProTube2.x
OpeninProTube2_FRAMEWORKS = Foundation UIKit

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 backboardd"
