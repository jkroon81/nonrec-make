bin = test2 test5
test2-sources = main2.c kalle/puh.S sven/katt.S
test2-libs = $(builddir)/../subdir2/libfoo.a
test2-ccflags = -I$(srcdir)/../subdir2
kalle/puh.S-asflags := -g
test5-sources = main5.c nils/gen.c
test5-ccflags = -I$(srcdir)/../subdir2
test5-libs = $(builddir)/../subdir2/libfoo.a
subdir = subdir2
built-sources = sven/katt.S nils/gen.c

$(builddir)/nils/gen.c : $(srcdir)/include.mk
	$(gen)touch $@

$(builddir)/sven/katt.S : $(srcdir)/include.mk
	$(gen)touch $@
