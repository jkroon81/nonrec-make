bin = test2 whoop
test2-sources = main2.c kalle/puh.S sven/katt.S
test2-libs = $(builddir)/../subdir2/libfoo.a
test2-ccflags = -I$(srcdir)/../subdir2
test2-kalle/puh.S-asflags := -g
whoop-sources = main2.c nils/gen.c
whoop-ccflags = -I$(srcdir)/../subdir2
whoop-libs = $(builddir)/../subdir2/libfoo.a
subdir = subdir2
built-sources = test2-sven/katt.S whoop-nils/gen.c

$(builddir)/whoop-nils/gen.c : $(srcdir)/include.mk
	$(gen)touch $@

$(builddir)/test2-sven/katt.S : $(srcdir)/include.mk
	$(gen)touch $@
