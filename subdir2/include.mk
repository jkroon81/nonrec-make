bin = test4
lib = libfoo.a
test4-sources = main4.c
libfoo.a-sources = foo.c libextra/deep/thing.c libextra/bar.c
libextra/deep/thing.c-ccflags = -O3
