print-filter := $(.VARIABLES) print-filter \n

O ?= build

mkdirs :=
default_v := 0
no-deps := $(filter clean% print-%,$(MAKECMDGOALS))

tvar = $(patsubst ./%,%,$(builddir)/$1)
trim-end = $(if $(filter %$1,$2),$(call trim-end,$1,$(patsubst %$1,%,$2)),$2)
normpath = $(patsubst $(CURDIR)/%,%,$(abspath $1))
objdir = $(if $(findstring /,$2),/$1-$(call trim-end,/,$(dir $2)))
prepend-unique = $(if $(filter $1,$($2)),,$2 := $1 $($2))

o := $(call trim-end,/,$O)

define \n


endef

define add_cmd
$1_0 = @echo "$2 $$(or $$(patsubst $o/%,%,$4),.)";
$1_  = $$($1_$(default_v))
$1   = $$($1_$(V))$3
endef

q_0 = @
q_  = $(q_$(default_v))
q   = $(q_$(V))

$(eval $(call add_cmd,$(strip ar     ),AR     ,ar,$$@))
$(eval $(call add_cmd,$(strip ranlib ),RANLIB ,ranlib,$$@))
$(eval $(call add_cmd,$(strip as     ),AS     ,as,$$@))
$(eval $(call add_cmd,$(strip cc     ),CC     ,gcc -c,$$(basename $$@).o))
$(eval $(call add_cmd,$(strip ccas   ),CCAS   ,gcc -S,$$(basename $$@).s))
$(eval $(call add_cmd,$(strip cpp    ),CPP    ,gcc -E,$$(basename $$@).i))
$(eval $(call add_cmd,$(strip ccld   ),CCLD   ,gcc,$$@))
$(eval $(call add_cmd,$(strip objdump),OBJDUMP,objdump -rd,$$@))
$(eval $(call add_cmd,$(strip clean  ),CLEAN  ,rm -f,$$(@:clean-%=%)))

define add_asm_to_obj_rule
$$(builddir)/$1-%.o : $$(srcdir)/%.S \
                      Makefile \
                      $$(srcdir)/include.mk
	$$(as) $$($$@-asflags) $$< -o $$@
endef

define add_c_to_obj_rule
$$(builddir)/$1-%.d $$(builddir)/$1-%.o : $$(srcdir)/%.c \
                                          Makefile \
                                          $$(srcdir)/include.mk
	$$(cc) $$($$(basename $$@).o-ccflags) -MMD -MP $$< \
	       -o $$(basename $$@).o
endef

define add_c_to_asm_rule
$$(builddir)/$1-%.d $$(builddir)/$1-%.s : $$(srcdir)/%.c \
                                          Makefile \
                                          $$(srcdir)/include.mk
	$$(ccas) $$($$(basename $$@).o-ccflags) -MMD -MP $$< \
	         -o $$(basename $$@).s
endef

define add_c_to_cpp_rule
$$(builddir)/$1-%.d $$(builddir)/$1-%.i : $$(srcdir)/%.c \
                                          Makefile \
                                          $$(srcdir)/include.mk
	$$(cpp) $$($$(basename $$@).o-ccflags) -MMD -MP $$< \
	        -o $$(basename $$@).i
endef

define add_obj_to_objdump_rule
$$(builddir)/$1-%.b : $$(builddir)/$1-%.o \
                      Makefile \
                      $$(srcdir)/include.mk
	$$(objdump) $$< > $$@
endef

define add_asmsrc
$$(eval $$(call tvar,$1-$(2:.S=.o))-asflags := $$(patsubst %,%,\
  $$(asflags) \
  $$($1-asflags) \
  $$($1-$2-asflags)))
cleanfiles += $$(builddir)/$$(basename $1-$2).[bo]
$$(eval $$(call tvar,$1)-objs += $$(builddir)/$1-$(2:.S=.o))
$$(eval $$(call prepend-unique,$$(builddir)$$(call objdir,$1,$2),mkdirs))
$$(addprefix $$(builddir)/$1-$$(basename $2),.b .o) : \
  | $$(builddir)$$(call objdir,$1,$2)
objdump : $$(builddir)/$1-$(2:.S=.b)
undefine $1-$2-asflags
endef

define add_csrc
$$(eval $$(call tvar,$1-$(2:.c=.o))-ccflags := $$(patsubst %,%,\
  $$(ccflags) \
  $$($1-ccflags) \
  $$($1-$2-ccflags)))
$$(if $(no-deps),,$$(eval -include $$(builddir)/$1-$(2:.c=.d)))
cleanfiles += $$(builddir)/$$(basename $1-$2).[bdios]
$$(eval $$(call tvar,$1)-objs += $$(builddir)/$1-$(2:.c=.o))
$$(eval $$(call prepend-unique,$$(builddir)$$(call objdir,$1,$2),mkdirs))
$$(addprefix $$(builddir)/$1-$$(basename $2),.b .d .i .o .s) : \
  | $$(builddir)$$(call objdir,$1,$2)
asm : $$(builddir)/$1-$(2:.c=.s)
cpp : $$(builddir)/$1-$(2:.c=.i)
objdump : $$(builddir)/$1-$(2:.c=.b)
undefine $1-$2-ccflags
endef

define add_bin
$$(eval $$(call tvar,$1)-libs := $$(call normpath,$$($1-libs)))
$$(foreach s,$$(filter %.S,$$(sort $$($1-sources))),$$(eval $$(call add_asmsrc,$1,$$s)))
$$(foreach s,$$(filter %.c,$$(sort $$($1-sources))),$$(eval $$(call add_csrc,$1,$$s)))
$$(eval $$(call add_asm_to_obj_rule,$1))
$$(eval $$(call add_c_to_obj_rule,$1))
$$(eval $$(call add_c_to_asm_rule,$1))
$$(eval $$(call add_c_to_cpp_rule,$1))
$$(eval $$(call add_obj_to_objdump_rule,$1))
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
$$(foreach s,$$(filter %.S,$$(sort $$($1-sources))),$$(eval $$(call add_asmsrc,$1,$$s)))
$$(foreach s,$$(filter %.c,$$(sort $$($1-sources))),$$(eval $$(call add_csrc,$1,$$s)))
$$(eval $$(call add_asm_to_obj_rule,$1))
$$(eval $$(call add_c_to_obj_rule,$1))
$$(eval $$(call add_c_to_asm_rule,$1))
$$(eval $$(call add_c_to_cpp_rule,$1))
$$(eval $$(call add_obj_to_objdump_rule,$1))
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
cleanfiles :=
bin :=
lib :=
subdir :=
mkdirs := $$(builddir) $$(mkdirs)
asflags := $$($$(call normpath,$$(builddir)/..)-asflags)
ccflags := $$($$(call normpath,$$(builddir)/..)-ccflags)
include $$(srcdir)/include.mk
subdir := $$(call trim-end,/,$$(subdir))
$$(eval $$(builddir)-asflags := $$(asflags))
$$(eval $$(builddir)-ccflags := $$(ccflags))
$$(foreach b,$$(bin),$$(eval $$(call add_bin,$$b)))
$$(foreach l,$$(lib),$$(eval $$(call add_lib,$$l)))
$$(eval $$(builddir)-cleanfiles := $$(cleanfiles))
.PHONY : clean-$$(builddir)/
clean : clean-$$(builddir)/
clean-$$(builddir)/ :
	$$(clean) $$($$(@:clean-%/=%)-cleanfiles)
$$(foreach s,$$(subdir),$$(eval $$(call add_subdir,$$(if $1,$1/)$$s)))
undefine srcdir
undefine builddir
undefine cleanfiles
undefine bin
undefine lib
undefine subdir
undefine asflags
undefine ccflags
endef

all :

$(eval $(call add_subdir,))

$(mkdirs) :
	$(q)mkdir -p $@

clean :
	$(q)for d in $(mkdirs); do [ -d $$d ] && rmdir $$d || true; done

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

.PHONY : all asm clean cpp print-% print-data-base print-variables
