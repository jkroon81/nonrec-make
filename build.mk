ifndef parse-build
cmdline-vars := $(foreach v,$(MAKEOVERRIDES),$(word 1,$(subst =, ,$v)))
startup-vars := $(filter-out $(cmdline-vars),$(.VARIABLES)) startup-vars
MAKEFLAGS := --no-builtin-rules --no-builtin-variables --no-print-directory
relpath-simple = $(patsubst /%,%,$(patsubst $2%,%,$1))
parent = $(patsubst %/,%,$(dir $1))
anc = $(if $(patsubst $3/%,,$1/ $2/),$(call anc,$1,$2,$(call parent,$3)),$3)
down-path = $(call relpath-simple,$(or $3,$1),$(call anc,$1,$2,$(or $3,$1)))
space := $(subst ,, )
replace = $(subst $(space),,$(patsubst %,$2,$(subst $1, ,$3)))
up-path = $(call replace,/,../,$(call down-path,$1,$2,$2))
relpath-calc = $(patsubst %/,%,$(call up-path,$1,$2)$(call down-path,$1,$2))
relpath-abs = $(or $(call relpath-$(if $(filter $2/%,$1/),simple,calc),$1,$2),.)
relpath = $(call relpath-abs,$(abspath $1),$(or $(abspath $2),$(CURDIR)))
abs-top-srcdir := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
top-srcdir := $(call relpath,$(abs-top-srcdir))
abs-init-srcdir ?= $(abspath $(dir $(firstword $(MAKEFILE_LIST))))
init-srcdir := $(call relpath,$(abs-init-srcdir))
abs-init-builddir ?= $(if $O,$(abspath $O),$(CURDIR))
init-builddir := $(call relpath,$(abs-init-builddir))
abs-top-builddir := $(abspath $(init-builddir)/$(call relpath, \
  $(top-srcdir),$(init-srcdir)))
top-builddir := $(call relpath,$(abs-top-builddir))

$(if $(and $O,$(filter-out $(init-builddir),$(top-builddir))), \
  $(error Out-of-tree build only supported from top build directory) \
)

flags := env asflags ccflags ldflags
configs := $(wildcard $(addprefix $(top-srcdir)/config/,\
  $(subst -, ,$(notdir $(abs-top-builddir)))))

define capture-flags
$(foreach v,$1,$(eval $v :=)) \
$(foreach f,$2,$(eval -include $f)) \
$(foreach v,$1,$(eval $3-$v := $($v))) \
$(foreach v,$1,$(eval undefine $v))
endef

$(call capture-flags,$(flags),$(top-srcdir)/common.mk,common)
$(call capture-flags,$(flags),$(configs),config)

verbose := $(if $(filter $(or $V,0),0),,1)
add-vvar = $1 = $(if $(verbose),$3,$2)

$(eval $(call add-vvar,q,@))

ifndef second-make
targets := $(or $(MAKECMDGOALS),all)
.DEFAULT_GOAL := $(targets)
.PHONY : $(targets)
$(wordlist 2,$(words $(targets)),$(targets)) :
	$(q)true
$(firstword $(targets)) : keep := MAKEFLAGS TERM
$(firstword $(targets)) : | $(top-builddir)
	$(q)env -i $(foreach v,$(keep),$v='$($v)') $(SHELL) $(.SHELLFLAGS) \
	  'export PATH && $(if $(config-env),. $(config-env) &&) \
	  $(MAKE) -C $(top-builddir) $(MAKECMDGOALS) \
	  -f $(call relpath,$(top-srcdir)/build.mk,$(top-builddir)) \
	  O= second-make=1 config-env= \
	  abs-init-srcdir=$(abs-init-srcdir) \
	  abs-init-builddir=$(abs-init-builddir)'
$(top-builddir) :
	$(q)mkdir -p $@
else
.DEFAULT_GOAL := all
mkdirs :=
skip-deps := $(filter clean print-%,$(MAKECMDGOALS))

bpath = $(call relpath,$(builddir)/$1)
if-arg = $(if $2,$1 $2)
tflags = _$(call bpath,$1)-$2
reverse = $(if $1,$(call reverse,$(wordlist 2,$(words $1),$1)) $(firstword $1))
makefile-deps = $(top-srcdir)/build.mk $(wildcard $(top-srcdir)/common.mk) \
  $(configs) $(srcdir)/Makefile

vpath %.c $(top-srcdir)
vpath %.S $(top-srcdir)

AR      ?= $(CROSS_COMPILE)ar
AS      ?= $(CROSS_COMPILE)as
CC      ?= $(CROSS_COMPILE)gcc
OBJDUMP ?= $(CROSS_COMPILE)objdump

add-vcmd-arg = $(call add-vvar,$1,@printf "  %-9s %s\n" $2 \
  $$(call relpath,$3,$(init-builddir));$4,$4)
add-vcmd = $(call add-vcmd-arg,$(or $2,$1_v),$1,$(or $4,$$@),$(or $3,$$($1)))

$(eval $(call add-vcmd,AR))
$(eval $(call add-vcmd,AS))
$(eval $(call add-vcmd,CC))
$(eval $(call add-vcmd,CCAS,,$$(CC)))
$(eval $(call add-vcmd,CCLD,,$$(CC)))
$(eval $(call add-vcmd,CPP,,$$(CC)))
$(eval $(call add-vcmd,OBJDUMP))
$(eval $(call add-vcmd,CLEAN,,rm -f,$$(subst ~,/,$$*)))
$(eval $(call add-vcmd,DISTCLEAN,,rm -f,$$(subst ~,/,$$*)))
$(eval $(call add-vcmd,GEN,gen))

%.o : %.S
	$(AS_v) $(_$@-asflags) $< -o $@
%.o : %.c
	$(CC_v) -c -MMD -MP $(_$@-ccflags) $< -o $@
%.s : %.c
	$(CCAS_v) -S $(_$*.o-ccflags) $< -o $@
%.i : %.c
	$(CPP_v) -E $(_$*.o-ccflags) $< -o $@
%.b : %.o
	$(OBJDUMP_v) -rd $< > $@

b-dep := objdump
i-dep := cpp
s-dep := asm

.S-flags-var := asflags
.S-flags-env := ASFLAGS
.S-built-suffixes := b o
.c-flags-var := ccflags
.c-flags-env := CFLAGS
.c-built-suffixes := b i o s
.c-extra-suffixes := d

define add-source
$(call tflags,$2.o,$($3-flags-var)) := $(strip \
  $(common-$($3-flags-var)) \
  $(config-$($3-flags-var)) \
  $($($3-flags-var)) \
  $($1-$($3-flags-var)) \
  $($2$3-$($3-flags-var)) \
  $($($3-flags-env)) \
)
$(if $(skip-deps),,-include $(builddir)/$2.d)
cleanfiles += $(call bpath,$2.[$(subst $(space),,\
  $(sort $($3-built-suffixes) $($3-extra-suffixes)))])
$(call tflags,$1,objs) += $(call bpath,$2.o)
mkdirs += $(call bpath,$2/..)
$(addprefix $(builddir)/$2.,$($3-built-suffixes)) : \
  $(makefile-deps) $(call if-arg,|,$(filter-out .,$(call bpath,$2/..)))
$(foreach s,$($3-built-suffixes),$(eval $($s-dep) : $(builddir)/$2.$s))
undefine $2$3-$($3-flags-var)
endef

define add-bin-lib-common
mkdirs += $(call bpath,$1/..)
$(call tflags,$1,libs) := $(foreach l,$($1-libs),$(call relpath,$l))
$(foreach s,$(sort $($1-sources)),$(eval \
  $(call add-source,$1,$(basename $s),$(suffix $s))))
all : $(builddir)/$1
$(builddir)/$1 : $($(call tflags,$1,objs)) $$($(call tflags,$1,libs)) \
  $(makefile-deps) $(call if-arg,|,$(filter-out .,$(call bpath,$1/..)))
$(builddir)/$1.b : $(builddir)/$1
	$$(OBJDUMP_v) -rd $$< > $$@
objdump : $(call bpath,$1.b)
cleanfiles += $(call bpath,$1) $(call bpath,$1.b)
undefine $1-sources
undefine $1-asflags
undefine $1-ccflags
undefine $1-ldflags
undefine $1-libs
endef

define add-bin
$(call add-bin-lib-common,$1)
$(call tflags,$1,ldflags) := $(strip \
  $(common-ldflags) \
  $(config-ldflags) \
  $(ldflags) \
  $($1-ldflags) \
  $(LDFLAGS) \
)
$(builddir)/$1 :
	$$(CCLD_v) $$(_$$@-ldflags) $$(_$$@-objs) $$(_$$@-libs) -o $$@
endef

define add-lib
$(call add-bin-lib-common,$1)
$(builddir)/$1 :
	$$(q)rm -f $$@
	$$(AR_v) cDrs $$@ $$(_$$@-objs)
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
all : $(builddir)/Makefile
$(builddir)/Makefile : $(top-srcdir)/build.mk | $(builddir)
	$$(gen)$$(file > $$@,$$(call gen-makefile,$(srcdir),$(builddir)))
distcleanfiles += $(call bpath,Makefile)
endef

subdir-vars := srcdir builddir cleanfiles distcleanfiles bin lib subdir \
  built-sources is-gen-makefile asflags ccflags ldflags

define add-subdir
$(foreach v,$(subdir-vars),$$(eval undefine $v))
srcdir := $(call relpath,$(top-srcdir)/$1)
builddir := $1
include $$(srcdir)/Makefile
$$(if $$(is-gen-makefile),,$$(eval $$(call parse-subdir,$1)))
$(foreach v,$(subdir-vars),$$(eval undefine $v))
endef

define parse-subdir
subdir := $(if $(subdir), \
  $(patsubst %/,%,$(subdir)), \
  $(notdir $(call parent,$(wildcard $(srcdir)/*/Makefile))))
cleanfiles += $(addprefix $(builddir)/,$(built-sources))
$(foreach s,$(built-sources),$(eval $(builddir)/$s : | $(call bpath,$s/..)))
$(foreach b,$(bin),$(eval $(call add-bin,$b)))
$(foreach l,$(lib),$(eval $(call add-lib,$l)))
$(if $(filter $(top-srcdir),$(top-builddir)),,$(call add-makefile))
$(call tflags,.,cleanfiles) := $$(cleanfiles)
$(call tflags,.,distcleanfiles) := $$(distcleanfiles)
clean     :     _clean-$(subst /,~,$(builddir))
distclean : _distclean-$(subst /,~,$(builddir))
$$(foreach s,$$(subdir),$$(eval $$(call add-subdir,$$(call relpath,$1/$$s))))
endef

parse-build := 1
$(eval $(call add-subdir,$(call relpath,$(init-srcdir),$(top-srcdir))))

mkdirs := $(call reverse,$(sort $(filter-out .,$(mkdirs))))

$(mkdirs) :
	$(q)mkdir -p $@

_clean-% :
	$(call if-arg,$(CLEAN_v),$(_$(subst ~,/,$*)-cleanfiles))

_distclean-% : _clean-%
	$(call if-arg,$(DISTCLEAN_v),$(_$(subst ~,/,$*)-distcleanfiles))

clean :             $(CURDIR)-rmdir-flags := --ignore-fail-on-non-empty
distclean : $(abs-top-srcdir)-rmdir-flags := --ignore-fail-on-non-empty
clean distclean :
	$(q)for d in $(mkdirs); do \
	    if [ -d $$d ]; then \
	        rmdir $($(CURDIR)-rmdir-flags) $$d; \
	    fi \
	done

print-% :
	$(q)echo $*=$($*)

print-data-base :
	$(q)$(MAKE) -f $(init-srcdir)/Makefile -pq $(if $(verbose),, \
	  | sed -e '/^\#/d' -e '/^$$/d') || true

print-variables :
	$(foreach v,$(sort $(if $(verbose),$(.VARIABLES),$(filter-out \
	  $(startup-vars),$(.VARIABLES)))),$(info $v=$(value $v)))
	@true

.PHONY : all asm clean distclean cpp print-% print-data-base print-variables

endif
endif
