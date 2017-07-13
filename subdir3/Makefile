ld-staticlib := bar
ld-sharedlib := bir
bar-sources := bar.vala
bar-valaflags := --pkg=posix
bir-sources := bir.vala
bir-valaflags := --pkg=posix
bar.vala.o-ccflags := -Wno-unused-parameter
bir.vala.o-ccflags := -Wno-unused-parameter

include $(dir $(lastword $(MAKEFILE_LIST)))../make/build.mk
