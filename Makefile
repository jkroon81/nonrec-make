print-filter := $(.VARIABLES) print-filter \n

O ?= build

cleanfiles :=
mkdirs :=
default_v := 0
no-deps := $(filter clean print-%,$(MAKECMDGOALS))

tvar = $(patsubst ./%,%,$(builddir)/$1)
trim-end = $(if $(filter %$1,$2),$(call trim-end,$1,$(patsubst %$1,%,$2)),$2)
normpath = $(patsubst $(CURDIR)/%,%,$(abspath $1))

o := $(call trim-end,/,$O)

define \n


endef

define add_cmd
$1_0 = @echo "$2 $$(patsubst $o/%,%,$4)";
$1_  = $$($1_$(default_v))
$1   = $$($1_$(V))$3
endef

q_0 = @
q_  = $(q_$(default_v))
q   = $(q_$(V))

$(eval $(call add_cmd,$(strip ar    ),AR    ,ar,$$@))
$(eval $(call add_cmd,$(strip ranlib),RANLIB,ranlib,$$@))
$(eval $(call add_cmd,$(strip as    ),AS    ,as,$$@))
$(eval $(call add_cmd,$(strip cc    ),CC    ,gcc,$$(basename $$@).o))
$(eval $(call add_cmd,$(strip ccld  ),CCLD  ,gcc,$$@))

define add_asm_rule
$$(builddir)/$1-%.o : $$(srcdir)/%.S \
                      Makefile \
                      $$(srcdir)/include.mk \
                      | $$(builddir)
	$$(as) $$($$@-asflags) $$< -o $$@
endef

define add_c_rule
$$(builddir)/$1-%.d $$(builddir)/$1-%.o : $$(srcdir)/%.c \
                                          Makefile \
                                          $$(srcdir)/include.mk \
                                          | $$(builddir)
	$$(cc) $$($$(basename $$@).o-ccflags) -MMD -MP -c $$< \
	       -o $$(basename $$@).o
endef

define add_asmsrc
$$(eval $$(call tvar,$1-$(2:.S=.o))-asflags := $$($1-asflags))
cleanfiles += $$(builddir)/$1-$(2:.S=.o)
$$(eval $$(call tvar,$1)-objs += $$(builddir)/$1-$(2:.S=.o))
endef

define add_csrc
$$(eval $$(call tvar,$1-$(2:.c=.o))-ccflags := $$($1-ccflags))
$$(if $(no-deps),,$$(eval -include $$(builddir)/$1-$(2:.c=.d)))
cleanfiles += $$(builddir)/$1-$(2:.c=.o) $$(builddir)/$1-$(2:.c=.d)
$$(eval $$(call tvar,$1)-objs += $$(builddir)/$1-$(2:.c=.o))
endef

define add_bin
$$(eval $$(call tvar,$1)-libs := $$(call normpath,$$($1-libs)))
$$(eval $$(call tvar,$1)-objs :=)
$$(foreach s,$$(filter %.S,$$($1-sources)),$$(eval $$(call add_asmsrc,$1,$$s)))
$$(foreach s,$$(filter %.c,$$($1-sources)),$$(eval $$(call add_csrc,$1,$$s)))
$$(eval $$(call add_asm_rule,$1))
$$(eval $$(call add_c_rule,$1))
all : $$(builddir)/$1
$$(builddir)/$1 : $$($$(call tvar,$1)-objs) \
                  $$($$(call tvar,$1)-libs) \
                  Makefile \
                  $$(srcdir)/include.mk \
                  | $$(builddir)
	$$(ccld) $$($$@-objs) $$($$@-libs) -o $$@
cleanfiles += $$(builddir)/$1
undefine $1-sources
undefine $1-ccflags
undefine $1-libs
endef

define add_lib
$$(eval $$(call tvar,$1)-objs :=)
$$(foreach s,$$(filter %.S,$$($1-sources)),$$(eval $$(call add_asmsrc,$1,$$s)))
$$(foreach s,$$(filter %.c,$$($1-sources)),$$(eval $$(call add_csrc,$1,$$s)))
$$(eval $$(call add_asm_rule,$1))
$$(eval $$(call add_c_rule,$1))
all : $$(builddir)/$1
$$(builddir)/$1 : $$($$(call tvar,$1)-objs) \
                  Makefile \
                  $$(srcdir)/include.mk \
                  | $$(builddir)
	$$(q)rm -f $$@
	$$(ar) cru $$@ $$($$@-objs)
	$$(ranlib) $$@
cleanfiles += $$(builddir)/$1
undefine $1-sources
endef

define add_subdir
srcdir := $$(if $1,$1,.)
builddir := $$(if $o,$o,.)$$(if $1,/$1)
bin :=
lib :=
subdir :=
mkdirs := $$(builddir) $$(mkdirs)
include $$(srcdir)/include.mk
subdir := $$(call trim-end,/,$$(subdir))
$$(foreach b,$$(bin),$$(eval $$(call add_bin,$$b)))
$$(foreach l,$$(lib),$$(eval $$(call add_lib,$$l)))
$$(foreach s,$$(subdir),$$(eval $$(call add_subdir,$$(if $1,$1/)$$s)))
undefine srcdir
undefine builddir
undefine bin
undefine lib
undefine subdir
endef

all :

$(eval $(call add_subdir,))

cleanfiles := $(strip $(cleanfiles))

$(mkdirs) :
	$(q)mkdir -p $@

clean :
	rm -f $(cleanfiles)
	$(if $o,$(foreach d,$(mkdirs),[ -d $d ] && rmdir $d || true$(\n)))

print-%: ; $(q)echo $*=$($*)

print-data-base :
	$(q)$(MAKE) -pq || true

print-variables :
	$(q)$(foreach v,$(sort $(filter-out $(print-filter),$(.VARIABLES))),\
	  $(if $(findstring $(\n),$(value $v)),\
	    $(info $v)$(info ---)$(info $(value $v))$(info ),\
	    $(info $v=$(value $v))\
	  )\
	)

.PHONY : all clean print-% print-data-base print-variables
