target-types += rust-bin

RUSTC ?= rustc

$(eval $(call add-vcmd,RUSTC))
$(eval $(call add-vcmd,RUSTLD,,$$(RUSTC) --emit=link))

define add-rust-bin
mkdirs += $(call bpath,$1/..)

all : $(builddir)/$1
$(builddir)/$1 : $$($(call tflags,$1,rlibs)) $(makefile-deps) \
  $(call if-arg,|,$(filter-out .,$(call bpath,$1/..)))
	$$(RUSTC_v) $$(_$$@-rlibs) -o $$@
objdump : $(call bpath,$1.b)
cleanfiles += $1 $1.[bd]
undefine $1-sources
-include $(builddir)/$1.d
endef
