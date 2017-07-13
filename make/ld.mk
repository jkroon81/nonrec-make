subdir-vars    += ldflags
ld-target-vars += sources staticlibs sharedlibs ldflags
target-types   += ld-bin ld-staticlib ld-sharedlib

AR      ?= $(CROSS_COMPILE)ar
OBJDUMP ?= $(CROSS_COMPILE)objdump

$(eval $(call add-vcmd,AR))
$(eval $(call add-vcmd,OBJDUMP))

%.b : %.o
	$(OBJDUMP_v) -rd $< > $@
%.b : %
	$(OBJDUMP_v) -rd $< > $@

b-dep := objdump

.PHONY : objdump

ld-staticlib-filename  = $(call relpath,$(dir $1)lib$(notdir $1).a)
ifeq ($(os),Windows_NT)
ld-sharedlib-filename  = $(call relpath,$(dir $1)$(notdir $1).dll)
else
ifeq ($(os),GNU/Linux)
ld-sharedlib-filename  = $(call relpath,$(dir $1)lib$(notdir $1).so)
else
$(error Unsupported OS '$(os)')
endif
endif

define add-ld-source
$(if $(filter $(origin add-ld-$3-source),undefined),\
  $(error Unknown source for '$1': $2.$3))
cleanfiles += $(addprefix $2.,$($3-built-suffixes) $($3-extra-suffixes))
mkdirs += $(call bpath,$2/..)
$($3-built-suffixes:%=$(builddir)/$2.%) : $(makefile-deps) \
  $(call if-arg,|,$(filter-out .,$(call bpath,$2/..)))
$(foreach s,$($3-built-suffixes),$(eval $($s-dep) : $(builddir)/$2.$s))
$(call add-ld-$3-source,$1,$2)
endef

add-ld-sources = $(if $3,$(call $0-real,$1,$2,$3,$4,$5))
define add-ld-sources-real
$(eval $(call add-ld-$4-$5,$1,$2))
$(eval $(call add-ld-$4-sources,$1,$2,$3,$5))
endef

define add-ld-header
mkdirs += $(call bpath,$1/..)
$(foreach t,$(src-fmts),$(eval \
  $(call add-ld-sources,$1,$2,$(filter %.$t,$($1-sources)),$t,$3)))
$(foreach s,$($1-sources),$(eval \
  $(call add-ld-source,$1,$(basename $s),$(patsubst .%,%,$(suffix $s)))))
$(foreach t,static shared,$(foreach l,$($1-$tlibs),$(eval \
  $(call add-ld-$tlib-dep,$1,$(call ld-$tlib-filename,$l),$(notdir $l),$3))))
all-targets += $(builddir)/$1
$(builddir)/$1 : $($(call tflags,$1,objs)) $(makefile-deps) \
  $(call if-arg,|,$(filter-out .,$(call bpath,$1/..)))
objdump : $(call bpath,$1.b)
cleanfiles += $1 $1.b
endef

add-ld-footer = $(foreach v,$(ld-target-vars),\
  $(eval undefine $1-$v) \
  $(eval undefine $(call tflags,$1,$v-append)))

add-ld-staticlib-dep = $(call tflags,$1,objs) += $2

define add-ld-sharedlib-dep
$(builddir)/$1 : $2
$(call tflags,$1,ldflags-append) += -L$(dir $2) -l$3
$(call $0-$4-$(os),$1,$2)
endef

define add-ld-sharedlib-dep-bin-Windows_NT
$(builddir)/$1 : $(builddir)/$(dir $1)$(notdir $2)
$(call add-hardlink,$(dir $1)$(notdir $2),$2)
endef

define add-ld-sharedlib-dep-bin-GNU/Linux
$(call tflags,$1,ldflags-append) += -Wl,-rpath=$(abspath $(dir $2))
endef

define add-ld-bin
$(call add-ld-header,$1,$1,bin)
$(call collect-flags,$1,ldflags,LDFLAGS)
$(builddir)/$1 :
	$$(if $$(_$$@-linker),,$$(error No linker for target '$$@'))
	$$(_$$@-linker) $$(_$$@-objs) $$(_$$@-ldflags) -o $$@
$(call add-ld-footer,$1,bin)
endef

add-ld-lib = $(call $0-real,$(call ld-$2-filename,$1),$1,$2)
define add-ld-lib-real
$(foreach f,$(ld-target-vars),$(eval $1-$f := $($2-$f))$(eval undefine $2-$f))
$(call add-ld-$3-real,$1,$2)
endef

add-ld-staticlib = $(call add-ld-lib,$1,staticlib)
define add-ld-staticlib-real
$(call add-ld-header,$1,$2,staticlib)
$(builddir)/$1 :
	$$(q)rm -f $$@
	$$(AR_v) cDrs $$@ $$(_$$@-objs)
$(call add-ld-footer,$1,staticlib)
endef

add-ld-sharedlib = $(call add-ld-lib,$1,sharedlib)
define add-ld-sharedlib-real
$(eval $(call tflags,$1,ccflags-append) += -fpic)
$(call add-ld-header,$1,$2,sharedlib)
$(call collect-flags,$1,ldflags,LDFLAGS)
$(builddir)/$1 :
	$$(if $$(_$$@-linker),,$$(error No linker for target '$$@'))
	$$(_$$@-linker) -shared $$(_$$@-objs) $$(_$$@-ldflags) -o $$@
$(call add-ld-footer,$1,sharedlib)
endef
