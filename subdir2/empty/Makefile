custom-built := test8

$(builddir)/test8 : $(srcdir)/Makefile
	$(gen)touch $@

include $(dir $(lastword $(MAKEFILE_LIST)))../../make/build.mk
