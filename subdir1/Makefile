bin := test2 robert/test5
test2-sources := main2.c kalle/puh.S sven/katt.S
test2-objects := $(top-builddir)/subdir2/libfoo.a
test2-ccflags := -I$(top-srcdir)/subdir2
kalle/puh.o-asflags := --reduce-memory-overheads
robert/test5-sources := main5.c nils/gen.c
robert/test5-ccflags := -I$(srcdir)/../subdir2
robert/test5-objects := $(builddir)/../subdir2/libfoo.a
built-sources := sven/katt.S nils/gen.c

define phony-c-file
#ifndef NEEDED_DEFINE
#error need define
#endif
endef

$(builddir)/nils/gen.c : $(srcdir)/Makefile
	$(gen)$(file > $@,$(call phony-c-file))

$(builddir)/sven/katt.S : $(srcdir)/Makefile
	$(gen)touch $@

include $(dir $(lastword $(MAKEFILE_LIST)))../build.mk
