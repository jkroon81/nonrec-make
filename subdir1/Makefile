ld-bin = test2 robert/test5
ld-sharedlib = shared
test2-sources = main2.c kalle/puh.S sven/katt.S
test2-staticlibs = $(top-builddir)/subdir2/foo
test2-cflags = -I$(top-srcdir)/subdir2
test2-ldflags = -Wl,-z -Wl,noexecstack
kalle/puh.o-asflags = --reduce-memory-overheads
robert/test5-sources = main5.c nils/gen.c
robert/test5-cflags = -I$(top-srcdir)/subdir2
robert/test5-staticlibs = $(builddir)/../subdir2/foo
shared-sources = shared.c
custom-built = sven/katt.S nils/gen.c

define phony-c-file
#if !defined(NEEDED_COMMON_DEFINE) || !defined(NEEDED_COMMON_OS_DEFINE)
#error need define
#endif
endef

$(builddir)/nils/gen.c : $(srcdir)/Makefile | $(builddir)/nils
	$(gen)$(file > $@,$(call phony-c-file))

$(builddir)/sven/katt.S : $(srcdir)/Makefile | $(builddir)/sven
	$(gen)touch $@

include $(dir $(lastword $(MAKEFILE_LIST)))../make/build.mk
