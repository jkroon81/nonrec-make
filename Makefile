ld-bin := test1
test1-sources := main1.c asm.S
test1-ccflags := $(shell pkg-config glib-2.0 --cflags) -I$(srcdir)/include
test1-ldflags := $(shell pkg-config glib-2.0 --libs)

include $(dir $(lastword $(MAKEFILE_LIST)))build.mk
