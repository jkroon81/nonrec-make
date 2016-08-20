abs-top-srcdir := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
MAKEFLAGS := --no-builtin-rules --no-builtin-variables --no-print-directory

ifdef O
$(eval $(shell mkdir -p $O))
$(or $(MAKECMDGOALS),_target) :
	@$(MAKE) -C $O -f $(abs-top-srcdir)/Makefile $(@:_target=) O=
else
objs :=
mkdirs :=
default-v := 0
no-deps := $(filter clean print-%,$(MAKECMDGOALS))
top-srcdir := $(shell realpath --relative-to $(CURDIR) $(abs-top-srcdir))

bdir = $(filter-out .,$(call trim-end,/,$(dir $(builddir)/$1)))
bfile = $(patsubst ./%,%,$(builddir)/$1)
sfile = $(patsubst ./%,%,$(srcdir)/$1)
trim-start = $(if $(filter $1%,$2),$(call trim-start,$1,$(2:$1%=%)),$2)
trim-end   = $(if $(filter %$1,$2),$(call trim-end  ,$1,$(2:%$1=%)),$2)
norm-path = $(call trim-start,/,$(patsubst $(CURDIR)%,%,$(abspath $1)))
prepend-unique = $(if $(filter $1,$($2)),,$2 := $1 $($2))

vpath %.c $(top-srcdir)
vpath %.S $(top-srcdir)

define add-cmd
$2-0 = @echo "$1$4";
$2-  = $$($2-$(default-v))
$2   = $$($2-$(V))$3
endef

q-0 = @
q-  = $(q-$(default-v))
q   = $(q-$(V))

$(eval $(call add-cmd,  AR      ,ar,ar,$$@))
$(eval $(call add-cmd,  RANLIB  ,ranlib,ranlib,$$@))
$(eval $(call add-cmd,  AS      ,as,as,$$@))
$(eval $(call add-cmd,  CC      ,cc,gcc -c,$$@))
$(eval $(call add-cmd,  CCAS    ,ccas,gcc -S,$$@))
$(eval $(call add-cmd,  CPP     ,cpp,gcc -E,$$@))
$(eval $(call add-cmd,  CCLD    ,ccld,gcc,$$@))
$(eval $(call add-cmd,  OBJDUMP ,objdump,objdump -rd,$$@))
$(eval $(call add-cmd,  CLEAN   ,clean,rm -f,$$(@:_clean-%=%)))
$(eval $(call add-cmd,  GEN     ,gen,,$$@))

%.o : %.S
	$(as) $($@-asflags) $< -o $@
%.o : %.c
	$(cc) $($@-ccflags) -MMD -MP $< -o $@
%.s : %.c
	$(ccas) $($(@:%.s=%.o)-ccflags) -MMD -MP $< -o $@
%.i : %.c
	$(cpp) $($(@:%.i=%.o)-ccflags) -MMD -MP $< -o $@
%.b : %.o
	$(objdump) $< > $@

b-dep = objdump : $1
i-dep = cpp : $1
s-dep = asm : $1

.S-flags := asflags
.S-targets := b o
.c-flags := ccflags
.c-targets := b d i o s

define add-source
$(if $(filter $(call bfile,$2.o),$(objs)),$(error Multiple $(call bfile,$2.o)))
objs += $(call bfile,$2.o)
$(eval $(call bfile,$2.o)-$($3-flags) := \
  $($($3-flags)) $($1-$($3-flags)) $($2$3-$($3-flags)))
$(if $(no-deps),,-include $(builddir)/$2.d)
cleanfiles += $(call bfile,$2.[$(subst $(subst ,, ),,$($3-targets)]))
$(eval $(call bfile,$1)-objs += $(call bfile,$2.o))
$(eval $(call prepend-unique,$(call bdir,$2),mkdirs))
$(addprefix $(builddir)/$2,$(addprefix .,$($3-targets))) : \
  $($(builddir)-makefile-deps) | $(call bdir,$2)
$(foreach s,$($3-targets),$(eval $(call $s-dep,$(builddir)/$2.$s)))
undefine $2$3-$($3-flags)
endef

define add-bin-lib-common
$(eval $(call bfile,$1)-libs := $(call norm-path,$($1-libs)))
$(foreach s,$(sort $($1-sources)),$(eval \
  $(call add-source,$1,$(basename $s),$(suffix $s))))
all : $(builddir)/$1
$(builddir)/$1 : $($(call bfile,$1)-objs) $($(call bfile,$1)-libs) \
                 $($(builddir)-makefile-deps) | $(builddir)
cleanfiles += $(call bfile,$1)
undefine $1-sources
undefine $1-asflags
undefine $1-ccflags
undefine $1-libs
endef

define add-bin
$(eval $(call add-bin-lib-common,$1))
$(builddir)/$1 :
	$$(ccld) $$($$@-objs) $$($$@-libs) -o $$@
endef

define add-lib
$(eval $(call add-bin-lib-common,$1))
$(builddir)/$1 :
	$$(q)rm -f $$@
	$$(ar) cru $$@ $$($$@-objs)
	$$(ranlib) $$@
endef

define add-subdir
srcdir := $(patsubst ./%,%,$(top-srcdir)$(if $1,/$1))
builddir := $(if $1,$1,.)
cleanfiles :=
bin :=
lib :=
subdir :=
built-sources :=
$(if $1,mkdirs := $1 $(mkdirs))
asflags := $$($$(or $$(call norm-path,$$(builddir)/..),.)-asflags)
ccflags := $$($$(or $$(call norm-path,$$(builddir)/..),.)-ccflags)
$$(eval $$(builddir)-makefile-deps := $(if $1,,$$(call sfile,Makefile)))
$$(eval $$(builddir)-makefile-deps += $$($$(or $$(call norm-path,\
  $$(builddir)/..),.)-makefile-deps) $$(call sfile,include.mk))
include $$(srcdir)/include.mk
subdir := $$(call trim-end,/,$$(subdir))
cleanfiles += $$(addprefix $$(builddir)/,$$(built-sources))
$$(foreach s,$$(built-sources),$$(eval $$(builddir)/$$s : | $$(call bdir,$$s)))
$$(eval $$(builddir)-asflags := $$(asflags))
$$(eval $$(builddir)-ccflags := $$(ccflags))
$$(foreach b,$$(bin),$$(eval $$(call add-bin,$$b)))
$$(foreach l,$$(lib),$$(eval $$(call add-lib,$$l)))
$$(eval $$(builddir)-cleanfiles := $$(cleanfiles))
.PHONY : _clean-$$(builddir)
clean : _clean-$$(builddir)
_clean-$$(builddir) :
	$$(clean) $$($$(@:_clean-%=%)-cleanfiles)
$$(foreach s,$$(subdir),$$(eval $$(call add-subdir,$(if $1,$1/)$$s)))
undefine srcdir
undefine builddir
undefine cleanfiles
undefine bin
undefine lib
undefine subdir
undefine built-sources
undefine asflags
undefine ccflags
endef

all :

$(eval $(call add-subdir,))

$(mkdirs) :
	$(q)mkdir -p $@

clean : $(abs-top-srcdir)-rmdir-flags := --ignore-fail-on-non-empty
clean :
	$(q)for d in $(mkdirs); do \
	    if [ -d $$d ]; then \
	        rmdir $($(CURDIR)-rmdir-flags) $$d; \
	    fi \
	done

print-%: ; $(q)echo $*=$($*)

print-data-base :
	$(q)$(MAKE) -f $(top-srcdir)/Makefile -pq || true

.PHONY : all asm clean cpp print-% print-data-base

endif
