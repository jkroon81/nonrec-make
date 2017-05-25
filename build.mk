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

$(if $(filter-out $(call relpath,$(init-srcdir),$(top-srcdir)), \
                  $(call relpath,$(init-builddir),$(top-builddir))), \
  $(error Out-of-tree build only supported from top build directory))

configs := $(wildcard $(addprefix $(top-srcdir)/config/,\
  $(subst -, ,$(notdir $(abs-top-builddir)))))

define capture-flags
$(eval old-vars := $(.VARIABLES)) \
$(foreach f,$1,$(eval -include $f)) \
$(eval new-vars := $(filter-out old-vars $(old-vars),$(.VARIABLES))) \
$(foreach v,$(new-vars),$(eval $2-$v := $($v))$(eval undefine $v)) \
$(foreach v,old-vars new-vars,$(eval undefine $v))
endef

$(call capture-flags,$(top-srcdir)/common.mk,common)
$(call capture-flags,$(configs),config)

verbose := $(if $(filter $(or $V,0),0),,1)
q := $(if $(verbose),,@)

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
map = $(foreach a,$2,$(call $1,$a))
vpath-build := $(if $(filter-out $(top-srcdir),$(top-builddir)),1)
target-types := ld-bin ld-staticlib
ld-target-vars := sources objects asflags ccflags ldflags
src-fmts := S c
subdir-vars := srcdir builddir cleanfiles distcleanfiles subdir \
  built-sources is-gen-makefile $(ld-target-vars) $(target-types)
add-vcmd-arg = $1 = $(if $(verbose),$3,@printf "  %-9s %s\n" $2 \
  $$(call relpath,$4,$(init-builddir));$3)
add-vcmd = $(call add-vcmd-arg,$(or $2,$1_v),$1,$(or $3,$$($1)),$(or $4,$$@))

$(if $(vpath-build),$(eval vpath %.c $(top-srcdir)))
$(if $(vpath-build),$(eval vpath %.S $(top-srcdir)))

AR      ?= $(CROSS_COMPILE)ar
AS      ?= $(CROSS_COMPILE)as
CC      ?= $(CROSS_COMPILE)gcc
OBJDUMP ?= $(CROSS_COMPILE)objdump

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
%.b : %
	$(OBJDUMP_v) -rd $< > $@

b-dep := objdump
i-dep := cpp
s-dep := asm

S-built-suffixes := b o
c-built-suffixes := b i o s
c-extra-suffixes := d

define collect-flags
$(call tflags,$1,$2) := $(strip \
  $(common-$2) \
  $(config-$2) \
  $($2) \
  $(foreach f,$4 $1,$($f-$2)) \
  $($3))
undefine $1-$2
endef

define add-ld-c-source
$(if $(skip-deps),,-include $(builddir)/$2.d)
$(call collect-flags,$2.o,ccflags,CFLAGS,$1)
$(call tflags,$1,objs) += $(call bpath,$2.o)
endef

define add-ld-S-source
$(call collect-flags,$2.o,asflags,ASFLAGS,$1)
$(call tflags,$1,objs) += $(call bpath,$2.o)
endef

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
distcleanfiles += Makefile
endef

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
cleanfiles += $(built-sources)
$(foreach s,$(built-sources),$(eval $(builddir)/$s : | $(call bpath,$s/..)))
$(foreach t,$(target-types),$(foreach o,$($t),$(eval $(call add-$t,$o))))
$(if $(vpath-build),$(call add-makefile))
$(call tflags,.,cleanfiles) := $$(call map,bpath,$$(cleanfiles))
$(call tflags,.,distcleanfiles) := $$(call map,bpath,$$(distcleanfiles))
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

.PHONY : all clean distclean print-% print-data-base print-variables

endif
endif
