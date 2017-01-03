ifndef parse-build
O ?= .
MAKEFLAGS := --no-builtin-rules --no-builtin-variables --no-print-directory
relpath = $(shell realpath -m --relative-to $1 $2)
abs-top-srcdir := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
top-srcdir := $(call relpath,.,$(abs-top-srcdir))
abs-init-srcdir := $(abspath $(dir $(firstword $(MAKEFILE_LIST))))
init-srcdir := $(call relpath,.,$(abs-init-srcdir))
abs-top-builddir := $(abspath $O)
top-builddir := $(call relpath,.,$(abs-top-builddir))
flags := env asflags ccflags ldflags
fragments := $(wildcard $(addprefix $(top-srcdir)/config/,\
  $(filter-out . ..,$(subst -, ,$(notdir $(abs-top-builddir))))))

define capture-flags
$(foreach v,$1,$(eval $v :=))
$(foreach f,$2,$(eval -include $f))
$(foreach v,$1,$(eval $3-$v := $($v)))
$(foreach v,$1,$(eval undefine $v))
endef

$(eval $(call capture-flags,$(flags),$(top-srcdir)/common.mk,__common))
$(eval $(call capture-flags,$(flags),$(fragments),__build))

default-v := 0

q-0 = @
q-  = $(q-$(default-v))
q   = $(q-$(V))

ifndef second-make
$(eval $(shell mkdir -p $O))
target := $(or $(MAKECMDGOALS),_target)
.DEFAULT_GOAL := $(target)
.PHONY : $(target)
$(target) :
	$(q)$(if $(__build-env),. $(__build-env) && )$(MAKE) -C $O \
	  -f $(call relpath,$O,$(init-srcdir)/Makefile) \
	  $(filter-out _target,$@) O=. second-make=1 __build-env= \
	  top-builddir=$(call relpath,$(init-srcdir),$(top-srcdir)) \
	  builddir=. srcdir=$(call relpath,$O,$(init-srcdir))
else
.DEFAULT_GOAL := all
objs :=
mkdirs :=
no-deps := $(filter clean print-%,$(MAKECMDGOALS))

map = $(foreach a,$2,$(call $1,$a))
bpath = $(call npath,$(builddir)/$1)
spath = $(patsubst ./%,%,$(srcdir)/$1)
npath = $(if $(filter $(CURDIR)%,$(abspath $1)),$(patsubst /%,%,$(patsubst \
  $(CURDIR)%,%,$(abspath $1))),$1)
tflags = _$(or $(call bpath,$1),.)-$2
prepend-unique = $(if $(filter $1,$($2)),,$2 := $1 $($2))

vpath %.c $(init-srcdir)
vpath %.S $(init-srcdir)

define add-cmd
$2-0 = @echo "$1$4";
$2-  = $$($2-$(default-v))
$2   = $$($2-$(V))$(strip $3)
endef

AR      ?= ar
RANLIB  ?= ranlib
AS      ?= as
CC      ?= cc
OBJDUMP ?= objdump

$(eval $(call add-cmd,  AR        ,ar,$(AR),$$@))
$(eval $(call add-cmd,  RANLIB    ,ranlib,$(RANLIB),$$@))
$(eval $(call add-cmd,  AS        ,as,$(AS),$$@))
$(eval $(call add-cmd,  CC        ,cc,$(CC) -c -MMD -MP,$$@))
$(eval $(call add-cmd,  CCAS      ,ccas,$(CC) -S,$$@))
$(eval $(call add-cmd,  CPP       ,cpp,$(CC) -E,$$@))
$(eval $(call add-cmd,  CCLD      ,ccld,$(CC),$$@))
$(eval $(call add-cmd,  OBJDUMP   ,objdump,$(OBJDUMP) -rd,$$@))
$(eval $(call add-cmd,  CLEAN     ,clean,rm -f,$$(@:_clean-%=%)))
$(eval $(call add-cmd,  DISTCLEAN ,distclean,rm -f,$$(@:_distclean-%=%)))
$(eval $(call add-cmd,  GEN       ,gen,,$$@))

%.o : %.S
	$(as) $(strip $(_$@-asflags) $< -o $@)
%.o : %.c
	$(cc) $(strip $(_$@-ccflags) $< -o $@)
%.s : %.c
	$(ccas) $(strip $(_$(@:%.s=%.o)-ccflags) $< -o $@)
%.i : %.c
	$(cpp) $(strip $(_$(@:%.i=%.o)-ccflags) $< -o $@)
%.b : %.o
	$(objdump) $(strip $< > $@)

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
  $(__common-$($3-flags-var)) \
  $(__build-$($3-flags-var)) \
  $($($3-flags-var)) \
  $($1-$($3-flags-var)) \
  $($2$3-$($3-flags-var)) \
  $($($3-flags-env)) \
)
$(if $(no-deps),,-include $(builddir)/$2.d)
cleanfiles += $(call bpath,$2.[$(subst $(subst ,, ),,\
  $(sort $($3-built-suffixes) $($3-extra-suffixes)))])
$(eval $(call tflags,$1,objs) += $(call bpath,$2.o))
$(eval $(call prepend-unique,$(call bpath,$2/..),mkdirs))
$(addprefix $(builddir)/$2,$(addprefix .,$($3-built-suffixes))) : \
  $($(call tflags,.,makefile-deps)) | $(call bpath,$2/..)
$(foreach s,$($3-built-suffixes),$(eval $(call $s-dep,$(builddir)/$2.$s)))
undefine $2$3-$($3-flags-var)
endef

define add-bin-lib-common
$(eval $(call tflags,$1,libs) := $(call map,npath,$($1-libs)))
$(foreach s,$(sort $($1-sources)),$(eval \
  $(call add-source,$1,$(basename $s),$(suffix $s))))
all : $(builddir)/$1
$(builddir)/$1 : $($(call tflags,$1,objs)) $($(call tflags,$1,libs)) \
                 $($(call tflags,.,makefile-deps)) | $(builddir)
cleanfiles += $(call bpath,$1)
undefine $1-sources
undefine $1-asflags
undefine $1-ccflags
undefine $1-ldflags
undefine $1-libs
endef

define add-bin
$(eval $(call add-bin-lib-common,$1))
$(eval $(call tflags,$1,ldflags) := \
  $(__common-ldflags) \
  $(__build-ldflags) \
  $(ldflags) \
  $($1-ldflags) \
  $(LDFLAGS) \
)
$(builddir)/$1 :
	$$(ccld) $$(strip $$(_$$@-ldflags) $$(_$$@-objs) $$(_$$@-libs) -o $$@)
endef

define add-lib
$(eval $(call add-bin-lib-common,$1))
$(builddir)/$1 :
	$$(q)rm -f $$@
	$$(ar) crD $$@ $$(_$$@-objs)
	$$(ranlib) $$@
endef

define prep-for-subdir
override srcdir := $(patsubst ./%,%,$(init-srcdir)/$1)
override builddir := $1
cleanfiles :=
distcleanfiles :=
bin :=
lib :=
subdir :=
built-sources :=
include $$(srcdir)/Makefile
endef

define add-subdir
$(if $1,mkdirs := $1 $(mkdirs))
$$(eval $$(call tflags,.,makefile-deps) := \
  $(if $1,,$(top-srcdir)/build.mk $(fragments)) \
  $$($$(call tflags,..,makefile-deps)) $$(call spath,Makefile))
subdir := $$(patsubst %/,%,$$(subdir))
cleanfiles += $$(addprefix $$(builddir)/,$$(built-sources))
$$(if $$(filter $$(builddir),$$(srcdir)),, \
  $$(eval distcleanfiles += $$(call bpath,Makefile)))
$$(foreach s,$$(built-sources),$$(eval $$(builddir)/$$s : \
  | $$(call bpath,$$s/..)))
$$(foreach b,$$(bin),$$(eval $$(call add-bin,$$b)))
$$(foreach l,$$(lib),$$(eval $$(call add-lib,$$l)))
$$(eval $$(call tflags,.,cleanfiles) := $$(cleanfiles))
$$(eval $$(call tflags,.,distcleanfiles) := $$(distcleanfiles))
all : $$(builddir)/Makefile
$$(builddir)/Makefile : | $$(builddir)
	$$(gen)echo "$$(subst $$(newline),;,$$(call gen-makefile,$(call relpath,$(builddir),$(srcdir)),$(call relpath,$(srcdir),$(builddir))))" \
	| tr ";" "\n" > $$@
.PHONY : _clean-$$(builddir)
clean : _clean-$$(builddir)
_clean-$$(builddir) :
	$$(clean) $$(_$$(@:_clean-%=%)-cleanfiles)
.PHONY : _distclean-$$(builddir)
distclean : _distclean-$$(builddir)
_distclean-$$(builddir) : _clean-$$(builddir)
	$$(distclean) $$(_$$(@:_distclean-%=%)-distcleanfiles)
$$(foreach s,$$(subdir),$$(eval $$(call prep-for-subdir,$(if $1,$1/)$$s)) \
                        $$(eval $$(call add-subdir,$(if $1,$1/)$$s)))
undefine srcdir
undefine builddir
undefine cleanfiles
undefine distcleanfiles
undefine bin
undefine lib
undefine subdir
undefine built-sources
undefine asflags
undefine ccflags
undefine ldflags
endef

define gen-makefile
MAKEFLAGS := --no-builtin-rules --no-builtin-variables --no-print-directory
target := \$$(or \$$(MAKECMDGOALS),_target)
.DEFAULT_GOAL := \$$(target)
.PHONY : \$$(target)
\$$(target) :
	@\$$(MAKE) -C $1 \$$(filter-out _target,\$$@) O=$2 abs-top-builddir=$(abs-top-builddir)
endef

parse-build := 1
srcdir := $(init-srcdir)
builddir := .
$(eval $(call add-subdir,))

$(mkdirs) :
	$(q)mkdir -p $@

clean :
	$(q)for d in $(mkdirs); do \
	    if [ -d $$d ]; then \
	        rmdir --ignore-fail-on-non-empty $$d; \
	    fi \
	done

distclean : $(abs-top-srcdir)-rmdir-flags := --ignore-fail-on-non-empty
distclean :
	$(q)for d in $(mkdirs); do \
	    if [ -d $$d ]; then \
	        rmdir $($(CURDIR)-rmdir-flags) $$d; \
	    fi \
	done

print-%: ; $(q)echo $*=$($*)

print-data-base :
	$(q)$(MAKE) -f $(init-srcdir)/Makefile -pq || true

print-variables :
	$(foreach v,$(sort $(.VARIABLES)),$(info $v=$(value $v)))
	$(q)true

.PHONY : all asm clean distclean cpp print-% print-data-base print-variables

endif
endif