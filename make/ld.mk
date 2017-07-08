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

ld-staticlib-filename = $(call relpath,$(dir $1)lib$(notdir $1).a)
ld-staticlib-shortname = $(patsubst lib%.a,%,$(notdir $1))
ifeq ($(os),Windows_NT)
ld-sharedlib-filename  = $(call relpath,$(dir $1)$(notdir $1).dll)
ld-sharedlib-shortname = $(patsubst %.dll,%,$(notdir $1))
else
ifeq ($(os),GNU/Linux)
ld-sharedlib-filename  = $(call relpath,$(dir $1)lib$(notdir $1).so)
ld-sharedlib-shortname = $(patsubst lib%.so,%,$(notdir $1))
else
$(error Unsupported OS '$(os)')
endif
endif

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
$(eval $(call add-ld-$3-sources,$1,$2,$4))
endef

define add-ld-header
$(eval $1-staticlibs := $(call map,ld-staticlib-filename,$($1-staticlibs)))
$(eval $1-sharedlibs := $(call map,ld-sharedlib-filename,$($1-sharedlibs)))
mkdirs += $(call bpath,$1/..)
$(foreach t,$(src-fmts),$(eval \
  $(call add-ld-sources,$1,$(filter %.$t,$($1-sources)),$t,$2)))
$(foreach s,$($1-sources),$(eval \
  $(call add-ld-source,$1,$(basename $s),$(patsubst .%,%,$(suffix $s)))))
$(eval $(call tflags,$1,objs) += $(call map,relpath,$($1-staticlibs)))
$(foreach l,$($1-sharedlibs),\
  $(eval $(call add-ld-sharedlib-dep,$1,$(call relpath,$l),$2)))
all : $(builddir)/$1
$(builddir)/$1 : $($(call tflags,$1,objs)) $(makefile-deps) \
  $(call if-arg,|,$(filter-out .,$(call bpath,$1/..)))
objdump : $(call bpath,$1.b)
cleanfiles += $1 $1.b
endef

add-ld-footer = $(foreach v,$(ld-target-vars),\
  $(eval undefine $1-$v) \
  $(eval undefine $(call tflags,$1,$v-append)))

define add-ld-sharedlib-dep
$(builddir)/$1 : $2
$(call tflags,$1,ldflags-append) += \
  -L$(dir $2) \
  -l$(call ld-sharedlib-shortname,$2)
$(call $0-$3-$(os),$1,$2)
endef

define add-ld-sharedlib-dep-bin-Windows_NT
$(builddir)/$1 : $(call relpath,$(builddir)/$(dir $1)$(notdir $2))
$(call add-hardlink,$(call relpath,$(dir $1)$(notdir $2)),$2)
endef

define add-ld-sharedlib-dep-bin-GNU/Linux
$(call tflags,$1,ldflags-append) += -Wl,-rpath=$(abspath $(dir $2))
endef

define add-ld-bin
$(call add-ld-header,$1,bin)
$(call collect-flags,$1,ldflags,LDFLAGS)
$(builddir)/$1 :
	$$(if $$(_$$@-linker),,$$(error No linker for target '$$@'))
	$$(_$$@-linker) $$(_$$@-objs) $$(_$$@-ldflags) -o $$@
$(call add-ld-footer,$1,bin)
endef

define add-ld-lib
$(foreach f,$(ld-target-vars),\
  $(eval $(call ld-$2-filename,$1)-$f := $($1-$f))\
  $(eval undefine $1-$f))
$(call add-ld-$2-real,$(call ld-$2-filename,$1))
endef

add-ld-staticlib = $(call add-ld-lib,$1,staticlib)
define add-ld-staticlib-real
$(call add-ld-header,$1,staticlib)
$(builddir)/$1 :
	$$(q)rm -f $$@
	$$(AR_v) cDrs $$@ $$(_$$@-objs)
$(call add-ld-footer,$1,staticlib)
endef

add-ld-sharedlib = $(call add-ld-lib,$1,sharedlib)
define add-ld-sharedlib-real
$(eval $(call tflags,$1,ccflags-append) += -fpic)
$(call add-ld-header,$1,sharedlib)
$(call collect-flags,$1,ldflags,LDFLAGS)
$(builddir)/$1 :
	$$(if $$(_$$@-linker),,$$(error No linker for target '$$@'))
	$$(_$$@-linker) -shared $$(_$$@-objs) $$(_$$@-ldflags) -o $$@
$(call add-ld-footer,$1,sharedlib)
endef
