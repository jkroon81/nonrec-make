ld-bin := test4
ld-staticlib := foo
test4-sources := main4.c
test4-sharedlibs := $(builddir)/../subdir1/shared
foo-sources := foo.c libextra/deep/thing.c libextra/bar.c
libextra/deep/thing.o-ccflags := -fomit-frame-pointer

include $(dir $(lastword $(MAKEFILE_LIST)))../make/build.mk
