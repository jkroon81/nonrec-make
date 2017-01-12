bin := test1
test1-sources := main1.c asm.S
test1-ccflags := -I$(srcdir)/include

include $(dir $(lastword $(MAKEFILE_LIST)))build.mk
