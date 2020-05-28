ifndef parse-build
cmdline-vars := $(foreach v,$(MAKEOVERRIDES),$(word 1,$(subst =, ,$v)))
startup-vars := $(filter-out $(cmdline-vars),$(.VARIABLES)) startup-vars
MAKEFLAGS = --no-builtin-rules --no-builtin-variables --no-print-directory
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
abs-top-srcdir := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))..)
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
$(foreach v,$(new-vars),$(eval $2-$v = $(value $v))$(eval undefine $v)) \
$(foreach v,old-vars new-vars,$(eval undefine $v))
endef

$(call capture-flags,$(configs),config)

verbose := $(if $(filter $(or $V,0),0),,1)
q := $(if $(verbose),,@)

ifndef second-make
targets := $(or $(MAKECMDGOALS),all)
.DEFAULT_GOAL = $(targets)
.PHONY : $(targets)
$(wordlist 2,$(words $(targets)),$(targets)) :
	$(q)true
$(firstword $(targets)) : | $(top-builddir)
	$(q)unset MAKELEVEL && \
	$(if $(config-env),. $(config-env) &&) \
	$(MAKE) -C $(top-builddir) $(MAKECMDGOALS) \
	  -f $(call relpath,$(top-srcdir)/make/build.mk,$(top-builddir)) \
	  O= second-make=1 config-env= os=$(or $(OS),$(shell uname -o)) \
	  abs-init-srcdir=$(abs-init-srcdir) \
	  abs-init-builddir=$(abs-init-builddir)
$(top-builddir) :
	$(q)mkdir -p $@
else
.DEFAULT_GOAL = all
mkdirs =
skip-deps := $(filter clean print-%,$(MAKECMDGOALS))
bpath = $(call relpath,$(builddir)/$1)
if-arg = $(if $2,$1 $2)
tflags = _$(call bpath,$1)-$2
reverse = $(if $1,$(call reverse,$(wordlist 2,$(words $1),$1)) $(firstword $1))
map = $(foreach a,$2,$(call $1,$a))
vpath-build := $(if $(filter-out $(top-srcdir),$(top-builddir)),1)
subdir-vars = srcdir builddir cleanfiles distcleanfiles subdir \
  custom-built is-gen-makefile $(target-types)
mkfiles := $(wildcard $(top-srcdir)/make/*.mk)
src-fmts := $(patsubst %-source.mk,%,$(notdir $(filter %-source.mk,$(mkfiles))))
makefile-deps-static := $(wildcard $(top-srcdir)/header.mk $(top-srcdir)/common.mk) \
  $(mkfiles) $(configs)
makefile-deps = $(makefile-deps-static) $(srcdir)/Makefile
cols := $(shell bc <<< "`tput cols` - 12")

define add-vcmd-arg
$1 = $(if $(verbose),$3,@printf "  %-9s %.$(cols)s\n" $2 \
  "$$(call relpath,$4,$(init-builddir)) ($$?)";$3)
whitelist += $1 $2
endef

add-vcmd = $(call add-vcmd-arg,$(or $2,$1_v),$1,$(or $3,$$($1)),$(or $4,$$@))

$(eval $(call add-vcmd,CLEAN,,rm -f,$$(subst ~,/,$$*)))
$(eval $(call add-vcmd,DISTCLEAN,,rm -f,$$(subst ~,/,$$*)))
$(eval $(call add-vcmd,GEN,gen))
$(eval $(call add-vcmd,LN,,ln))

overrides := $(os) $(notdir $(configs))
collect-overrides = $($1) $(foreach o,$(overrides),$($1-$o))

define collect-flags
$(call tflags,$1,$2) = $(strip \
  $(call map,collect-overrides,common-$2 config-$2 $2 $4-$2 $1-$2) \
  $(foreach f,$4 $1,$($(call tflags,$f,$2-append))) \
  $($3))
undefine $1-$2
endef

define add-link
$(if $(filter $(origin $(call tflags,$1,source)),undefined),\
  $(eval $(call tflags,$1,source) = $2)\
    $(eval $(call add-$3link-real,$1,$2))\
    $(eval cleanfiles += $1),\
  $(if $(filter $($(call tflags,$1,source)),$2),,\
    $(error $1->$2 $3link already defined as $1->$($(call tflags,$1,source)))))
endef

add-symlink = $(call add-link,$1,$2,sym)
define add-symlink-real
$(builddir)/$1 : $2 | $(call bpath,$1/..)
	$$(LN_v) -sf $$(call relpath,$$<,$$(dir $$@)) $$@
endef

add-hardlink = $(call add-link,$1,$2,hard)
define add-hardlink-real
$(builddir)/$1 : $2 | $(call bpath,$1/..)
	$$(LN_v) -f $$< $$@
endef

define gen-makefile
is-gen-makefile = 1
ifndef parse-build
abs-init-srcdir = $(abspath $1)
abs-init-builddir := $$(if $$O,$$(abspath $$O),$$(CURDIR))
include $(call relpath,$(abs-top-srcdir)/make/build.mk,$2)
endif
endef

define add-makefile
mkdirs += $(builddir)
all : $(builddir)/Makefile
$(builddir)/Makefile : $(top-srcdir)/make/build.mk | $(builddir)
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
cleanfiles += $(custom-built)
$(foreach t,$(custom-built), \
  $(eval mkdirs += $(call bpath,$t/..)) \
  $(eval all : $(builddir)/$t))
$(foreach t,$(target-types),$(foreach o,$($t),$(eval $(call add-$t,$o))))
$(foreach s,$(subdir-hooks),$(eval $(call $s)))
$(if $(vpath-build),$(call add-makefile))
$(call tflags,.,cleanfiles) := $$(cleanfiles)
$(call tflags,.,distcleanfiles) := $$(distcleanfiles)
clean     :     _clean-$(subst /,~,$(builddir))
distclean : _distclean-$(subst /,~,$(builddir))
$$(foreach s,$$(subdir),$$(eval $$(call add-subdir,$$(call relpath,$1/$$s))))
endef

$(call capture-flags,$(top-srcdir)/common.mk,common)

$(foreach f,$(filter-out %/build.mk,$(mkfiles)),$(eval include $f))
parse-build = 1
pre-parse-vars := $(.VARIABLES)

-include $(top-srcdir)/header.mk
$(eval $(call add-subdir,$(call relpath,$(init-srcdir),$(top-srcdir))))

$(foreach v,builddir srcdir,\
  $(eval $v=$$(error '$v' is not valid in this context)))

mkdirs := $(call reverse,$(sort $(filter-out .,$(mkdirs))))

$(mkdirs) :
	$(q)mkdir -p $@

_clean-% :
	$(call if-arg,$(CLEAN_v),$(addprefix $(filter-out ./,\
	  $(subst ~,/,$*)/),$(_$(subst ~,/,$*)-cleanfiles)))

_distclean-% : _clean-%
	$(call if-arg,$(DISTCLEAN_v),$(addprefix $(filter-out ./,\
	  $(subst ~,/,$*)/),$(_$(subst ~,/,$*)-distcleanfiles)))

clean :             $(CURDIR)-rmdir-flags = --ignore-fail-on-non-empty
distclean : $(abs-top-srcdir)-rmdir-flags = --ignore-fail-on-non-empty
clean distclean :
	$(q)for d in $(mkdirs); do \
	    if [ -d $$d -a ! -h $$d ]; then \
	        rmdir $($(CURDIR)-rmdir-flags) $$d; \
	    fi \
	done

print-% :
	$(info $*=$(value $*))
	@true

print-data-base :
	$(q)$(MAKE) -f $(abs-init-srcdir)/Makefile -pq $(if $(verbose),, \
	  | sed -e '/^\#/d' -e '/^$$/d') || true

print-variables :
	$(foreach v,$(sort $(if $(verbose),$(.VARIABLES),$(filter-out \
	  $(startup-vars),$(.VARIABLES)))),$(info $v=$(value $v)))
	@true

.PHONY : all clean distclean print-% print-data-base print-variables

whitelist += abs-top-builddir abs-top-srcdir anc down-path gen-makefile \
  if-arg mkdirs parent q relpath relpath-abs relpath-calc relpath-simple \
  replace space top-builddir top-srcdir up-path verbose
$(foreach v,\
  $(filter-out $(whitelist) $(startup-vars),$(pre-parse-vars) pre-parse-vars),\
  $(eval undefine $v))
$(foreach v,config-env O second-make V,$(eval override undefine $v))

endif
endif
