ld-staticlib = bar
ld-sharedlib = bir
bar-sources = bar.vala
bar-valaflags = --pkg=posix
bir-sources = bir.vala
bir-valaflags = --pkg=posix
bar.o-cflags = -Wno-unused-parameter -Wno-unused-variable -Wno-cast-function-type
bir.o-cflags = -Wno-unused-parameter -Wno-unused-variable -Wno-cast-function-type

include $(dir $(lastword $(MAKEFILE_LIST)))../make/build.mk
