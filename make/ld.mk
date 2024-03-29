subdir-vars    += ldflags
ld-target-vars += sources staticlibs sharedlibs ldflags
target-types   += ld-bin ld-staticlib ld-sharedlib

ifeq ($(os),Windows_NT)
subdir-vars    += dlls
subdir-hooks   += collect-dlls
ld-target-vars += dlls
endif

AR      ?= $(CROSS_COMPILE)ar
OBJDUMP ?= $(CROSS_COMPILE)objdump

$(eval $(call add-vcmd,AR))
$(eval $(call add-vcmd,OBJDUMP))

%.b : %.o
	$(OBJDUMP_v) -Cdr $< > $@
%.b : %
	$(OBJDUMP_v) -Cdr $< > $@

b-dep = objdump

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
cleanfiles += $2.[$(subst $(space),,\
  $(sort $($3-built-suffixes) $($3-extra-suffixes)))]
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
all : $(builddir)/$1
$(builddir)/$1 : $($(call tflags,$1,objs)) $(makefile-deps) \
  $(call if-arg,|,$(filter-out .,$(call bpath,$1/..)))
objdump : $(call bpath,$1.b)
cleanfiles += $1 $1.b
endef

add-ld-footer = $(foreach v,$(ld-target-vars), \
  $(foreach n,$(filter $1-$v%,$(.VARIABLES)),$(eval undefine $n)) \
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
ifeq ($(os),Windows_NT)
$(call collect-flags,$1,dlls)
$(builddir)/$1 : $$(call map,bpath,$$(patsubst %,lib%.dll,$$($(call tflags,$1,dlls))))
$(call tflags,.,dlls) += $$($(call tflags,$1,dlls))
endif
$(call add-ld-footer,$1)
endef

add-ld-lib = $(call $0-real,$(call ld-$2-filename,$1),$1,$2)
define add-ld-lib-real
$(foreach v,$(ld-target-vars), \
  $(eval $1-$v = $(value $2-$v)) \
  $(foreach o,$(overrides),$(eval $1-$v-$o = $(value $2-$v-$o))) \
  $(foreach n,$(filter $2-$v%,$(.VARIABLES)),$(eval undefine $n)))
$(call add-ld-$3-real,$1,$2)
endef

add-ld-staticlib = $(call add-ld-lib,$1,staticlib)
define add-ld-staticlib-real
$(call add-ld-header,$1,$2,staticlib)
$(builddir)/$1 :
	$$(q)rm -f $$@
	$$(AR_v) cDrs $$@ $$(_$$@-objs)
$(call add-ld-footer,$1)
endef

add-ld-sharedlib = $(call add-ld-lib,$1,sharedlib)
define add-ld-sharedlib-real
$(call add-ld-header,$1,$2,sharedlib)
$(call collect-flags,$1,ldflags,LDFLAGS)
$(builddir)/$1 :
	$$(if $$(_$$@-linker),,$$(error No linker for target '$$@'))
	$$(_$$@-linker) -shared $$(_$$@-objs) $$(_$$@-ldflags) -o $$@
$(call add-ld-footer,$1)
endef

ifeq ($(os),Windows_NT)
define add-dll
mingw-sysroot := $(or $(mingw-sysroot),$(shell $(CROSS_COMPILE)gcc -print-sysroot)/)
$(call add-hardlink,lib$1.dll,$$(mingw-sysroot)mingw/bin/lib$1.dll)
endef
define collect-dlls
$(call tflags,.,dlls) := $(sort $($(call tflags,.,dlls)))
$$(foreach d,$$($(call tflags,.,dlls)),$$(eval $$(call add-dll,$$d)))
endef
endif
