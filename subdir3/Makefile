ld-staticlib = bar
ld-sharedlib = bir
bar-sources = bar.vala
bar-valaflags = --pkg=posix
bir-sources = bir.vala
bir-valaflags = --pkg=posix
bar.o-cflags = -Wno-unused-parameter -Wno-unused-variable -Wno-incompatible-pointer-types
bir.o-cflags = -Wno-unused-parameter -Wno-unused-variable -Wno-incompatible-pointer-types

include $(dir $(lastword $(MAKEFILE_LIST)))../make/build.mk
