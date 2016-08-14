top_srcdir := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
MAKEFLAGS := --no-builtin-rules --no-builtin-variables --no-print-directory

ifeq ($(abspath $(CURDIR)),$(top_srcdir))
O ?= build
else
O ?= .
endif

o := $(if $O,$O,.)

sub-make := $(if $(filter $(abspath $(CURDIR)),$(top_srcdir)),1,0)
sub-make += $(if $(filter .,$o),1,0)

ifeq ($(sub-make),1 1)
$(error srcdir = builddir not supported)
endif

ifneq ($(sub-make),0 1)
$(eval $(shell mkdir -p $o))
$(or $(MAKECMDGOALS),_target) :
	@$(MAKE) -C $o -f $(top_srcdir)/Makefile $(MAKECMDGOALS) O=.
else
vpath %.c $(top_srcdir)
vpath %.S $(top_srcdir)
vpath Makefile $(top_srcdir)

mkdirs :=
default-v := 0
no-deps := $(filter clean% print-%,$(MAKECMDGOALS))

tdir = $(filter-out .,$(call trim-end,/,$(dir $(builddir)/$1)))
tvar = $(patsubst ./%,%,$(builddir)/$1)
trim-start = $(if $(filter $1%,$2),$(call trim-start,$1,$(2:$1%=%)),$2)
trim-end   = $(if $(filter %$1,$2),$(call trim-end  ,$1,$(2:%$1=%)),$2)
norm-path = $(call trim-start,/,$(patsubst $(CURDIR)%,%,$(abspath $1)))
prepend-unique = $(if $(filter $1,$($2)),,$2 := $1 $($2))

define add-cmd
$2-0 = @echo "$1 $$(or $4,.)";
$2-  = $$($2-$(default-v))
$2   = $$($2-$(V))$3
endef

q-0 = @
q-  = $(q-$(default-v))
q   = $(q-$(V))

$(eval $(call add-cmd,AR     ,ar,ar,$$@))
$(eval $(call add-cmd,RANLIB ,ranlib,ranlib,$$@))
$(eval $(call add-cmd,AS     ,as,as,$$@))
$(eval $(call add-cmd,CC     ,cc,gcc -c,$$@))
$(eval $(call add-cmd,CCAS   ,ccas,gcc -S,$$@))
$(eval $(call add-cmd,CPP    ,cpp,gcc -E,$$@))
$(eval $(call add-cmd,CCLD   ,ccld,gcc,$$@))
$(eval $(call add-cmd,OBJDUMP,objdump,objdump -rd,$$@))
$(eval $(call add-cmd,CLEAN  ,clean,rm -f,$$(@:_clean-%=%)))
$(eval $(call add-cmd,GEN    ,gen,,$$@))

%.o : %.S Makefile
	$(as) $($@-asflags) $< -o $@
%.o : %.c Makefile
	$(cc) $($@-ccflags) -MMD -MP $< -o $@
%.s : %.c Makefile
	$(ccas) $($(@:.s=.o)-ccflags) -MMD -MP $< -o $@
%.i : %.c Makefile
	$(cpp) $($(@:.i=.o)-ccflags) -MMD -MP $< -o $@
%.b : %.o Makefile
	$(objdump) $< > $@

add-built-source = $(builddir)/$1 : | $(call tdir,$1)

define add-asmsrc
$(eval $(call tvar,$(2:.S=.o))-asflags := $(patsubst %,%,\
  $(asflags) $($1-asflags) $($2-asflags)))
cleanfiles += $(builddir)/$(basename $2).[bo]
$(eval $(call tvar,$1)-objs += $(call tvar,$(2:.S=.o)))
$(eval $(call prepend-unique,$(call tdir,$2),mkdirs))
$(addprefix $(builddir)/$(basename $2),.b .o) : \
  $(srcdir)/include.mk | $(call tdir,$2)
objdump : $(builddir)/$(2:.S=.b)
undefine $2-asflags
endef

define add-csrc
$(eval $(call tvar,$(2:.c=.o))-ccflags := $(patsubst %,%,\
  $(ccflags) $($1-ccflags) $($2-ccflags)))
$(if $(no-deps),,$(eval -include $(builddir)/$(2:.c=.d)))
cleanfiles += $(builddir)/$(basename $2).[bdios]
$(eval $(call tvar,$1)-objs += $(call tvar,$(2:.c=.o)))
$(eval $(call prepend-unique,$(call tdir,$2),mkdirs))
$(addprefix $(builddir)/$(basename $2),.b .d .i .o .s) : \
  $(srcdir)/include.mk | $(call tdir,$2)
asm : $(builddir)/$(2:.c=.s)
cpp : $(builddir)/$(2:.c=.i)
objdump : $(builddir)/$(2:.c=.b)
undefine $2-ccflags
endef

define add-bin-lib-common
$(eval $(call tvar,$1)-libs := $(call norm-path,$($1-libs)))
$(foreach s,$(filter %.S,$(sort $($1-sources))),\
  $(eval $(call add-asmsrc,$1,$s)))
$(foreach s,$(filter %.c,$(sort $($1-sources))),\
  $(eval $(call add-csrc,$1,$s)))
all : $(builddir)/$1
$(builddir)/$1 : $($(call tvar,$1)-objs) $($(call tvar,$1)-libs) \
                 Makefile $(srcdir)/include.mk | $(builddir)
cleanfiles += $(builddir)/$1
undefine $1-sources
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
srcdir := $(top_srcdir)$(if $1,/$1)
builddir := $(if $1,$1,.)
cleanfiles :=
bin :=
lib :=
subdir :=
built-sources :=
$(if $1,$$(eval mkdirs := $1 $(mkdirs)))
asflags := $$($$(or $$(call norm-path,$$(builddir)/..),.)-asflags)
ccflags := $$($$(or $$(call norm-path,$$(builddir)/..),.)-ccflags)
include $$(srcdir)/include.mk
subdir := $$(call trim-end,/,$$(subdir))
cleanfiles += $$(addprefix $$(builddir)/,$$(built-sources))
$$(foreach s,$$(built-sources),$$(eval $$(call add-built-source,$$s)))
$$(eval $$(builddir)-asflags := $$(asflags))
$$(eval $$(builddir)-ccflags := $$(ccflags))
$$(foreach b,$$(bin),$$(eval $$(call add-bin,$$b)))
$$(foreach l,$$(lib),$$(eval $$(call add-lib,$$l)))
$$(eval $$(builddir)-cleanfiles := $$(cleanfiles))
.PHONY : _clean-$$(builddir)
clean : _clean-$$(builddir)
_clean-$$(builddir) :
	$$(clean) $$($$(@:_clean-%=%)-cleanfiles)
$$(foreach s,$$(subdir),$$(eval $$(call add-subdir,$$(if $1,$1/)$$s)))
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

clean :
	$(q)for d in $(mkdirs); do [ -d $$d ] && rmdir $$d || true; done

print-%: ; $(q)echo $*=$($*)

print-data-base :
	$(q)$(MAKE) -f $(top_srcdir)/Makefile -pq || true

.PHONY : all asm clean cpp print-% print-data-base

endif
