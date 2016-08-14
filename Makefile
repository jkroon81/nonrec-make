print-filter := $(.VARIABLES) print-filter \n

O ?= build

mkdirs :=
default-v := 0
no-deps := $(filter clean% print-%,$(MAKECMDGOALS))

tdir = $(call trim-end,/,$(dir $(builddir)/$1))
tvar = $(patsubst ./%,%,$(builddir)/$1)
trim-start = $(if $(filter $1%,$2),$(call trim-start,$1,$(2:$1%=%)),$2)
trim-end   = $(if $(filter %$1,$2),$(call trim-end  ,$1,$(2:%$1=%)),$2)
norm-path = $(patsubst $(CURDIR)/%,%,$(abspath $1))
prepend-unique = $(if $(filter $1,$($2)),,$2 := $1 $($2))

o := $(call trim-end,/,$O)

define \n


endef

define add-cmd
$1-0 = @echo "$2 $$(or $$(call trim-start,/,$$(patsubst $o%,%,$4)),.)";
$1-  = $$($1-$(default-v))
$1   = $$($1-$(V))$3
endef

q-0 = @
q-  = $(q-$(default-v))
q   = $(q-$(V))

$(eval $(call add-cmd,$(strip ar     ),AR     ,ar,$$@))
$(eval $(call add-cmd,$(strip ranlib ),RANLIB ,ranlib,$$@))
$(eval $(call add-cmd,$(strip as     ),AS     ,as,$$@))
$(eval $(call add-cmd,$(strip cc     ),CC     ,gcc -c,$$(basename $$@).o))
$(eval $(call add-cmd,$(strip ccas   ),CCAS   ,gcc -S,$$(basename $$@).s))
$(eval $(call add-cmd,$(strip cpp    ),CPP    ,gcc -E,$$(basename $$@).i))
$(eval $(call add-cmd,$(strip ccld   ),CCLD   ,gcc,$$@))
$(eval $(call add-cmd,$(strip objdump),OBJDUMP,objdump -rd,$$@))
$(eval $(call add-cmd,$(strip clean  ),CLEAN  ,rm -f,$$(@:_clean-%=%)))
$(eval $(call add-cmd,$(strip gen    ),GEN    ,,$$@))

add-built-source = $(builddir)/$1 : | $(call tdir,$1)

define add-asmsrc
$$(eval $$(call tvar,$1-$(2:.S=.o))-asflags := $$(patsubst %,%,\
  $$(asflags) $$($1-asflags) $$($1-$2-asflags)))
cleanfiles += $$(builddir)/$$(basename $1-$2).[bo]
$$(eval $$(call tvar,$1)-objs += $$(builddir)/$1-$(2:.S=.o))
$$(eval $$(call prepend-unique,$$(call tdir,$1-$2),mkdirs))
$$(addprefix $$(builddir)/$1-$$(basename $2),.b .o) : | $$(call tdir,$1-$2)
objdump : $$(builddir)/$1-$(2:.S=.b)
undefine $1-$2-asflags
endef

define add-csrc
$$(eval $$(call tvar,$1-$(2:.c=.o))-ccflags := $$(patsubst %,%,\
  $$(ccflags) $$($1-ccflags) $$($1-$2-ccflags)))
$$(if $(no-deps),,$$(eval -include $$(builddir)/$1-$(2:.c=.d)))
cleanfiles += $$(builddir)/$$(basename $1-$2).[bdios]
$$(eval $$(call tvar,$1)-objs += $$(builddir)/$1-$(2:.c=.o))
$$(eval $$(call prepend-unique,$$(call tdir,$1-$2),mkdirs))
$$(addprefix $$(builddir)/$1-$$(basename $2),.b .d .i .o .s) : \
  | $$(call tdir,$1-$2)
asm : $$(builddir)/$1-$(2:.c=.s)
cpp : $$(builddir)/$1-$(2:.c=.i)
objdump : $$(builddir)/$1-$(2:.c=.b)
undefine $1-$2-ccflags
endef

define add-bin-lib-common
$$(eval $$(call tvar,$1)-libs := $$(call norm-path,$$($1-libs)))
$$(foreach s,$$(filter %.S,$$(sort $$($1-sources))),\
  $$(eval $$(call add-asmsrc,$1,$$s)))
$$(foreach s,$$(filter %.c,$$(sort $$($1-sources))),\
  $$(eval $$(call add-csrc,$1,$$s)))
$$(builddir)/$1-%.o : $$(srcdir)/%.S Makefile $$(srcdir)/include.mk
	$$(as) $$($$@-asflags) $$< -o $$@
$$(builddir)/$1-%.o : $$(srcdir)/%.c Makefile $$(srcdir)/include.mk
	$$(cc) $$($$@-ccflags) -MMD -MP $$< -o $$@
$$(builddir)/$1-%.s : $$(srcdir)/%.c Makefile $$(srcdir)/include.mk
	$$(ccas) $$($$(@:.s=.o)-ccflags) -MMD -MP $$< -o $$@
$$(builddir)/$1-%.i : $$(srcdir)/%.c Makefile $$(srcdir)/include.mk
	$$(cpp) $$($$(@:.i=.o)-ccflags) -MMD -MP $$< -o $$@
$$(builddir)/$1-%.b : $$(builddir)/$1-%.o Makefile $$(srcdir)/include.mk
	$$(objdump) $$< > $$@
$$(builddir)/$1-%.o : $$(builddir)/$1-%.S Makefile $$(srcdir)/include.mk
	$$(as) $$($$@-asflags) $$< -o $$@
$$(builddir)/$1-%.o : $$(builddir)/$1-%.c Makefile $$(srcdir)/include.mk
	$$(cc) $$($$@-ccflags) -MMD -MP $$< -o $$@
$$(builddir)/$1-%.s : $$(builddir)/$1-%.c Makefile $$(srcdir)/include.mk
	$$(ccas) $$($$(@:.s=.o)-ccflags) -MMD -MP $$< -o $$@
$$(builddir)/$1-%.i : $$(builddir)/$1-%.c Makefile $$(srcdir)/include.mk
	$$(cpp) $$($$(@:.i=.o)-ccflags) -MMD -MP $$< -o $$@
all : $$(builddir)/$1
$$(builddir)/$1 : $$($$(call tvar,$1)-objs) $$($$(call tvar,$1)-libs) \
                  Makefile $$(srcdir)/include.mk | $$(builddir)
cleanfiles += $$(builddir)/$1
undefine $1-sources
undefine $1-ccflags
undefine $1-libs
endef

define add-bin
$$(eval $$(call add-bin-lib-common,$1))
$$(builddir)/$1 :
	$$(ccld) $$($$@-objs) $$($$@-libs) -o $$@
endef

define add-lib
$$(eval $$(call add-bin-lib-common,$1))
$$(builddir)/$1 :
	$$(q)rm -f $$@
	$$(ar) cru $$@ $$($$@-objs)
	$$(ranlib) $$@
endef

define add-subdir
srcdir := $$(if $1,$1,.)
builddir := $$(if $o,$o,.)$$(if $1,/$1)
cleanfiles :=
bin :=
lib :=
subdir :=
built-sources :=
mkdirs := $$(builddir) $$(mkdirs)
asflags := $$($$(call norm-path,$$(builddir)/..)-asflags)
ccflags := $$($$(call norm-path,$$(builddir)/..)-ccflags)
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
	$(q)$(MAKE) -pq || true

print-variables :
	$(q)$(foreach v,$(sort $(filter-out $(print-filter),$(.VARIABLES))),\
	  $(if $(findstring $(\n),$(value $v)),\
	    $(info $v)$(info ---)$(info $(value $v))$(info ),\
	    $(info $v=$(value $v))\
	  )\
	)

.PHONY : all asm clean cpp print-% print-data-base print-variables
