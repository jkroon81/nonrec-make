subdir-vars    += ldflags
ld-target-vars += sources objects ldflags
target-types   += ld-bin ld-staticlib

AR      ?= $(CROSS_COMPILE)ar
CC      ?= $(CROSS_COMPILE)gcc
OBJDUMP ?= $(CROSS_COMPILE)objdump

$(eval $(call add-vcmd,AR))
$(eval $(call add-vcmd,CCLD,,$$(CC)))
$(eval $(call add-vcmd,OBJDUMP))

%.b : %.o
	$(OBJDUMP_v) -rd $< > $@
%.b : %
	$(OBJDUMP_v) -rd $< > $@

b-dep := objdump

.PHONY : objdump

define add-ld-source
$(if $(filter $(origin add-ld-$3-source),undefined),\
  $(error Unknown source for '$1': $2.$3))
cleanfiles += $2.[$(subst $(space),,\
  $(sort $($3-built-suffixes) $($3-extra-suffixes)))]
mkdirs += $(call bpath,$2/..)
$(addprefix $(builddir)/$2.,$($3-built-suffixes)) : \
  $(makefile-deps) $(call if-arg,|,$(filter-out .,$(call bpath,$2/..)))
$(foreach s,$($3-built-suffixes),$(eval $($s-dep) : $(builddir)/$2.$s))
$(call add-ld-$3-source,$1,$2)
endef

add-ld-sources = $(if $2,$(call add-ld-sources-real,$1,$2,$3,$4))
define add-ld-sources-real
$(eval $(call add-ld-$3-$4,$1))
$(eval $(call add-ld-$3-sources,$1,$2))
endef

define add-ld-header
mkdirs += $(call bpath,$1/..)
$(foreach t,$(src-fmts),$(eval \
  $(call add-ld-sources,$1,$(filter %.$t,$($1-sources)),$t,$2)))
$(foreach s,$($1-sources),$(eval \
  $(call add-ld-source,$1,$(basename $s),$(patsubst .%,%,$(suffix $s)))))
$(eval $(call tflags,$1,objs) += $(call map,relpath,$($1-objects)))
all : $(builddir)/$1
$(builddir)/$1 : $($(call tflags,$1,objs)) $(makefile-deps) \
  $(call if-arg,|,$(filter-out .,$(call bpath,$1/..)))
objdump : $(call bpath,$1.b)
cleanfiles += $1 $1.b
endef

define add-ld-footer
$(foreach v,$(addprefix $1-,$(ld-target-vars)),$(eval undefine $v))
endef

define add-ld-bin
$(call add-ld-header,$1,bin)
$(call collect-flags,$1,ldflags,LDFLAGS)
$(builddir)/$1 :
	$$(CCLD_v) $$(_$$@-objs) $$(_$$@-ldflags) -o $$@
$(call add-ld-footer,$1,bin)
endef

define add-ld-staticlib
$(call add-ld-header,$1,staticlib)
$(builddir)/$1 :
	$$(q)rm -f $$@
	$$(AR_v) cDrs $$@ $$(_$$@-objs)
$(call add-ld-footer,$1,staticlib)
endef
