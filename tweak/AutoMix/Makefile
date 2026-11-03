# The AutoMix planner helper, built on its own.
#
# Not part of the tweak's build: tweak/Makefile only reads tweak/Sources, so nothing here compiles in the normal
# build, and a tree without a Mac or the iOS 26 SDK still builds and ships. Build it by hand with
# `make -C tweak/AutoMix`, then put the dylib in the app's Frameworks beside the tweak (README.md).
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:16.1

include $(THEOS)/makefiles/common.mk

# The iOS 26 variant. The older one is the same files against SonicKit_MusicKit and Interface25.swift.
LIBRARY_NAME = SpotifyGlassAutoMix26
SpotifyGlassAutoMix26_FILES = SGAutoMix.swift Interface26.swift
SpotifyGlassAutoMix26_SWIFTFLAGS = -O -swift-version 5
SpotifyGlassAutoMix26_FRAMEWORKS = Foundation
SpotifyGlassAutoMix26_PRIVATE_FRAMEWORKS = _SonicKit_MusicKit_Packages
SpotifyGlassAutoMix26_INSTALL_PATH = /usr/lib

include $(THEOS_MAKE_PATH)/library.mk
