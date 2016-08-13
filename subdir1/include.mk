bin = test2
test2-sources = main2.c
test2-libs = $(builddir)/../subdir2/libfoo.a
test2-ccflags = -I$(srcdir)/../subdir2
subdir = subdir2
