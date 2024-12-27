ld-staticlib = bar
ld-sharedlib = bir
bar-sources = bar.vala
bar-valaflags = --pkg=posix
bir-sources = bir.vala
bir-valaflags = --pkg=posix
bar.o-cflags = -Wno-discarded-qualifiers -Wno-unused-parameter -Wno-unused-variable
bir.o-cflags = -Wno-discarded-qualifiers -Wno-unused-parameter -Wno-unused-variable

include $(dir $(lastword $(MAKEFILE_LIST)))../make/build.mk
