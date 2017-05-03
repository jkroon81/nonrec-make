target-types += rust-bin

RUSTC ?= rustc

$(eval $(call add-vcmd,RUSTC))

define add-rust-bin
mkdirs += $(call bpath,$1/..)
all : $(builddir)/$1
$(builddir)/$1 : $($1-sources:%=$(srcdir)/%) $(makefile-deps) \
  $(call if-arg,|,$(filter-out .,$(call bpath,$1/..)))
	$$(RUSTC_v) $($1-sources:%=$(srcdir)/%) \
	  --emit link=$$@ --emit dep-info=$$@.d
objdump : $(call bpath,$1.b)
cleanfiles += $1 $1.[bd]
undefine $1-sources
-include $(builddir)/$1.d
endef
