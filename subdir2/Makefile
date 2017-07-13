ld-bin := test4 test6
ld-staticlib := foo
test4-sources := main4.c
test4-sharedlibs := $(builddir)/../subdir1/shared
foo-sources := foo.c libextra/deep/thing.c libextra/bar.c
libextra/deep/thing.o-ccflags := -fomit-frame-pointer
test6-sources := main6.vala
test6-valaflags := --pkg=posix
test6-vala-staticlibs := $(builddir)/../subdir3/bar
test6-vala-sharedlibs := $(builddir)/../subdir3/bir
main6.vala.o-ccflags := -Wno-unused-parameter

include $(dir $(lastword $(MAKEFILE_LIST)))../make/build.mk
