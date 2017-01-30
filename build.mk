ifndef parse-build
startup-vars := $(.VARIABLES) startup-vars
MAKEFLAGS := --no-builtin-rules --no-builtin-variables --no-print-directory
parent = $(patsubst %/,%,$(dir $1))
anc = $(if $(or $(patsubst $3/%,,$1/),$(patsubst $3/%,,$2/)),$(call anc,$1,$2,$(call parent,$3)),$3)
space := $(subst ,, )
down-path = $(if $(filter $(call anc,$1,$2,$1),$3),,$(patsubst $(call anc,$1,$2,$1)/%,%,$3))
up-path = $(subst $(space),,$(patsubst %,../,$(subst /, ,$(call down-path,$1,$2,$3))))
relpath-calc = $(patsubst %/,%,$(call up-path,$1,$2,$2)$(call down-path,$1,$2,$1))
relpath-simple = $(patsubst /%,%,$(patsubst $(CURDIR)%,%,$1))
relpath-abs = $(strip $(if $2,$(call relpath-calc,$1,$2), \
                              $(if $(filter $(CURDIR)%,$1),$(call relpath-simple,$1), \
                                                           $(call relpath-calc,$1,$(CURDIR)))))
relpath = $(or $(call relpath-abs,$(abspath $1),$(if $2,$(abspath $2))),.)
abs-top-srcdir := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
top-srcdir := $(call relpath,$(abs-top-srcdir))
abs-init-srcdir ?= $(abspath $(dir $(firstword $(MAKEFILE_LIST))))
init-srcdir := $(call relpath,$(abs-init-srcdir))
abs-init-builddir ?= $(if $O,$(abspath $O),$(CURDIR))
init-builddir := $(call relpath,$(abs-init-builddir))
abs-top-builddir := $(abspath $(init-builddir)/$(call relpath,$(top-srcdir),$(init-srcdir)))
top-builddir := $(call relpath,$(abs-top-builddir))

$(if $(and $O,$(filter-out $(init-builddir),$(top-builddir))), \
  $(error Out-of-tree build only supported from top build directory) \
)

flags := env asflags ccflags ldflags
configs := $(wildcard $(addprefix $(top-srcdir)/config/,\
  $(subst -, ,$(notdir $(abs-top-builddir)))))

define capture-flags
$(foreach v,$1,$(eval $v :=))
$(foreach f,$2,$(eval -include $f))
$(foreach v,$1,$(eval $3-$v := $($v)))
$(foreach v,$1,$(eval undefine $v))
endef

$(eval $(call capture-flags,$(flags),$(top-srcdir)/common.mk,common))
$(eval $(call capture-flags,$(flags),$(configs),config))

default-V := 0

define add-vvar
$1-0 = $2
$1-1 = $3
$1-  = $$($1-$(default-V))
$1   = $$($1-$V)
endef

$(eval $(call add-vvar,q,@))

ifndef second-make
targets := $(or $(MAKECMDGOALS),all)
.DEFAULT_GOAL := $(targets)
.PHONY : $(targets)
$(wordlist 2,$(words $(targets)),$(targets)) :
	$(q)true
$(firstword $(targets)) : | $(top-builddir)
	$(q)$(if $(config-env),. $(config-env) && )$(MAKE) -C $(top-builddir) \
	  -f $(call relpath,$(top-srcdir)/build.mk,$(top-builddir)) \
	  $(MAKECMDGOALS) O= second-make=1 config-env= \
	  abs-init-srcdir=$(abs-init-srcdir) \
	  abs-init-builddir=$(abs-init-builddir)
$(top-builddir) :
	$(q)mkdir -p $@
else
.DEFAULT_GOAL := all
objs :=
mkdirs :=
no-deps := $(filter clean print-%,$(MAKECMDGOALS))

map = $(foreach a,$2,$(call $1,$a))
bpath = $(call relpath,$(builddir)/$1)
tflags = _$(call bpath,$1)-$2
prepend-unique = $(if $(filter $1,$($2)),,$2 := $1 $($2))

vpath %.c $(top-srcdir)
vpath %.S $(top-srcdir)

AR      ?= $(CROSS_COMPILE)ar
RANLIB  ?= $(CROSS_COMPILE)ranlib
AS      ?= $(CROSS_COMPILE)as
CC      ?= $(CROSS_COMPILE)gcc
OBJDUMP ?= $(CROSS_COMPILE)objdump

add-vcmd = $(call add-vvar,$(strip $1),@echo "$2";)

$(eval $(call add-vcmd,ar_v       ,  AR        $$@))
$(eval $(call add-vcmd,ranlib_v   ,  RANLIB    $$@))
$(eval $(call add-vcmd,as_v       ,  AS        $$@))
$(eval $(call add-vcmd,cc_v       ,  CC        $$@))
$(eval $(call add-vcmd,ccas_v     ,  CCAS      $$@))
$(eval $(call add-vcmd,cpp_v      ,  CPP       $$@))
$(eval $(call add-vcmd,ccld_v     ,  CCLD      $$@))
$(eval $(call add-vcmd,objdump_v  ,  OBJDUMP   $$@))
$(eval $(call add-vcmd,clean_v    ,  CLEAN     $$(@:_clean-%=%)))
$(eval $(call add-vcmd,distclean_v,  DISTCLEAN $$(@:_distclean-%=%)))
$(eval $(call add-vcmd,gen        ,  GEN       $$@))

%.o : %.S
	$(as_v)$(AS) $(strip $(_$@-asflags) $< -o $@)
%.o : %.c
	$(cc_v)$(CC) -c -MMD -MP $(strip $(_$@-ccflags) $< -o $@)
%.s : %.c
	$(ccas_v)$(CC) -S $(strip $(_$(@:%.s=%.o)-ccflags) $< -o $@)
%.i : %.c
	$(cpp_v)$(CC) -E $(strip $(_$(@:%.i=%.o)-ccflags) $< -o $@)
%.b : %.o
	$(objdump_v)$(OBJDUMP) -rd $(strip $< > $@)

b-dep = objdump : $1
i-dep = cpp : $1
s-dep = asm : $1

.S-flags-var := asflags
.S-flags-env := ASFLAGS
.S-built-suffixes := b o
.c-flags-var := ccflags
.c-flags-env := CFLAGS
.c-built-suffixes := b i o s
.c-extra-suffixes := d

define newline


endef

define add-source
$(if $(filter $(call bpath,$2.o),$(objs)),$(error Multiple $(call bpath,$2.o)))
objs += $(call bpath,$2.o)
$(eval $(call tflags,$2.o,$($3-flags-var)) := \
  $(common-$($3-flags-var)) \
  $(config-$($3-flags-var)) \
  $($($3-flags-var)) \
  $($1-$($3-flags-var)) \
  $($2$3-$($3-flags-var)) \
  $($($3-flags-env)) \
)
$(if $(no-deps),,-include $(builddir)/$2.d)
cleanfiles += $(call bpath,$2.[$(subst $(space),,\
  $(sort $($3-built-suffixes) $($3-extra-suffixes)))])
$(eval $(call tflags,$1,objs) += $(call bpath,$2.o))
$(eval $(call prepend-unique,$(call bpath,$2/..),mkdirs))
$(addprefix $(builddir)/$2.,$($3-built-suffixes)) : \
  $($(call tflags,.,makefile-deps)) | $(call bpath,$2/..)
$(foreach s,$($3-built-suffixes),$(eval $(call $s-dep,$(builddir)/$2.$s)))
undefine $2$3-$($3-flags-var)
endef

define add-bin-lib-common
$(eval $(call prepend-unique,$(call bpath,$1/..),mkdirs))
$(eval $(call tflags,$1,libs) := $(call map,relpath,$($1-libs)))
$(foreach s,$(sort $($1-sources)),$(eval \
  $(call add-source,$1,$(basename $s),$(suffix $s))))
all : $(builddir)/$1
$(builddir)/$1 : $($(call tflags,$1,objs)) $($(call tflags,$1,libs)) \
                 $($(call tflags,.,makefile-deps)) | $(call bpath,$1/..)
$(builddir)/$1.b : $(builddir)/$1
	$$(objdump_v)$(OBJDUMP) -rd $$(strip $$< > $$@)
objdump : $(call bpath,$1.b)
cleanfiles += $(call bpath,$1) $(call bpath,$1.b)
undefine $1-sources
undefine $1-asflags
undefine $1-ccflags
undefine $1-ldflags
undefine $1-libs
endef

define add-bin
$(eval $(call add-bin-lib-common,$1))
$(eval $(call tflags,$1,ldflags) := \
  $(common-ldflags) \
  $(config-ldflags) \
  $(ldflags) \
  $($1-ldflags) \
  $(LDFLAGS) \
)
$(builddir)/$1 :
	$$(ccld_v)$(CC) $$(strip $$(_$$@-ldflags) $$(_$$@-objs) $$(_$$@-libs) -o $$@)
endef

define add-lib
$(eval $(call add-bin-lib-common,$1))
$(builddir)/$1 :
	$$(q)rm -f $$@
	$$(ar_v)$(AR) crD $$@ $$(_$$@-objs)
	$$(ranlib_v)$(RANLIB) -D $$@
endef

define gen-makefile
is-gen-makefile := 1
ifndef parse-build
abs-init-srcdir := $(abspath $1)
abs-init-builddir := $$(if $$O,$$(abspath $$O),$$(CURDIR))
include $(call relpath,$(abs-top-srcdir)/build.mk,$2)
endif
endef

define add-makefile
all : $$(builddir)/Makefile
$$(builddir)/Makefile : $(top-srcdir)/build.mk | $$(builddir)
	$$(gen)$$(file > $$@,$$(call gen-makefile,$(srcdir),$(builddir)))
distcleanfiles += $$(call bpath,Makefile)
endef

define add-subdir
srcdir := $(call relpath,$(top-srcdir)/$1)
builddir := $1
cleanfiles :=
distcleanfiles :=
bin :=
lib :=
subdir :=
built-sources :=
is-gen-makefile :=
asflags :=
ccflags :=
ldflags :=
include $$(srcdir)/Makefile
$$(if $$(is-gen-makefile),,$$(eval $$(call parse-subdir,$1)))
undefine srcdir
undefine builddir
undefine cleanfiles
undefine distcleanfiles
undefine bin
undefine lib
undefine subdir
undefine built-sources
undefine is-gen-makefile
undefine asflags
undefine ccflags
undefine ldflags
endef

define parse-subdir
$$(eval $$(call tflags,.,makefile-deps) := \
  $(top-srcdir)/build.mk $(wildcard $(top-srcdir)/common.mk) \
  $(configs) $$(srcdir)/Makefile)
subdir := $$(if $$(subdir), \
  $$(patsubst %/,%,$$(subdir)), \
  $$(notdir $$(call parent,$$(wildcard $$(srcdir)/*/Makefile))))
cleanfiles += $$(addprefix $$(builddir)/,$$(built-sources))
$$(foreach s,$$(built-sources),$$(eval $$(builddir)/$$s : \
  | $$(call bpath,$$s/..)))
$$(foreach b,$$(bin),$$(eval $$(call add-bin,$$b)))
$$(foreach l,$$(lib),$$(eval $$(call add-lib,$$l)))
$(if $(filter $(top-srcdir),$(top-builddir)),,$(call add-makefile))
$$(eval $$(call tflags,.,cleanfiles) := $$(cleanfiles))
$$(eval $$(call tflags,.,distcleanfiles) := $$(distcleanfiles))
.PHONY clean : _clean-$$(builddir)
_clean-$$(builddir) :
	$$(clean_v)rm -f $$(_$$(@:_clean-%=%)-cleanfiles)
.PHONY distclean : _distclean-$$(builddir)
_distclean-$$(builddir) : _clean-$$(builddir)
	$$(distclean_v)rm -f $$(_$$(@:_distclean-%=%)-distcleanfiles)
$$(foreach s,$$(subdir),$$(eval $$(call add-subdir,$$(call relpath,$1/$$s))))
endef

parse-build := 1
$(eval $(call add-subdir,$(call relpath,$(init-srcdir),$(top-srcdir))))

mkdirs := $(filter-out .,$(mkdirs))

$(mkdirs) :
	$(q)mkdir -p $@

clean :             $(CURDIR)-rmdir-flags := --ignore-fail-on-non-empty
distclean : $(abs-top-srcdir)-rmdir-flags := --ignore-fail-on-non-empty
clean distclean :
	$(q)for d in $(mkdirs); do \
	    if [ -d $$d ]; then \
	        rmdir $($(CURDIR)-rmdir-flags) $$d; \
	    fi \
	done

print-%: ; $(q)echo $*=$($*)

print-data-base :
	$(q)$(MAKE) -f $(init-srcdir)/Makefile -pq || true

$(eval $(call add-vvar,varlist,$(filter-out $(startup-vars),$(.VARIABLES)),$(.VARIABLES)))

print-variables :
	$(foreach v,$(sort $(varlist)),$(info $v=$(value $v)))
	@true

.PHONY : all asm clean distclean cpp print-% print-data-base print-variables

endif
endif
