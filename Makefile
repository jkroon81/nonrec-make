ld-bin = test1 test7
test1-sources = main1.c asm.S
test1-cflags  = $(shell pkg-config glib-2.0 --cflags) -I$(top-srcdir)/include
test1-ldflags = $(shell pkg-config glib-2.0 --libs) -Wl,-z -Wl,noexecstack
test7-sources = main7.cpp

include $(dir $(lastword $(MAKEFILE_LIST)))make/build.mk
