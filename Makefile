print-filter := $(.VARIABLES) print-filter \n

O ?= build/

cleanfiles :=
mkdirs :=
default_v := 0

first = $(firstword $1)
rest = $(wordlist 2,$(words $1),$1)
reverse = $(strip $(if $1,$(call reverse,$(call rest,$1)) $(call first,$1)))
normpath = $(patsubst $(CURDIR)/%,%,$(abspath $1))

define \n


endef

define add_cmd
$1_0 = @echo "$2 $$(@:$O%=%)";
$1_  = $$($1_$(default_v))
$1   = $$($1_$(V))$3
endef

q_0 = @
q_  = $(q_$(default_v))
q   = $(q_$(V))

$(eval $(call add_cmd,$(strip ar    ),AR    ,ar))
$(eval $(call add_cmd,$(strip ranlib),RANLIB,ranlib))
$(eval $(call add_cmd,$(strip cc    ),CC    ,gcc))
$(eval $(call add_cmd,$(strip ccld  ),CCLD  ,gcc))

define add_csource
mkdirs := $(sort $(mkdirs) $O$1)
$O$1$2-$(3:.c=.o)-ccflags := $$($2-ccflags)
$O$1$2-$(3:.c=.o) : $1$3 Makefile $1include.mk | $O$1
	$$(cc) $$($$@-ccflags) -MMD -MP -c $$< -o $$@
-include $O$1$2-$(3:.c=.d)
cleanfiles += $O$1$2-$(3:.c=.o) $O$1$2-$(3:.c=.d)
undefine $2-ccflags
endef

define add_bin
mkdirs := $(sort $(mkdirs) $O$1)
$O$1$2-objs := $$(addprefix $O$1$2-,$$($2-sources:.c=.o))
$O$1$2-libs := $$(call normpath,$$(addprefix $O$1,$$($2-libs)))
all : $O$1$2
$O$1$2 : $$($O$1$2-objs) $$($O$1$2-libs) Makefile $1include.mk | $O$1
	$$(ccld) $$($$@-objs) $$($$@-libs) -o $$@
$$(foreach s,$$($2-sources),$$(eval $$(call add_csource,$1,$2,$$s)))
cleanfiles += $O$1$2
undefine $2-sources
undefine $2-libs
endef

define add_lib
mkdirs := $(sort $(mkdirs) $O$1)
$O$1lib$2.a-objs := $$(addprefix $O$1$2-,$$($2-sources:.c=.o))
all : $O$1lib$2.a
$O$1lib$2.a : $$($O$1lib$2.a-objs) Makefile $1include.mk | $O$1
	$(q)rm -f $$@
	$$(ar) cru $$@ $$($$@-objs)
	$$(ranlib) $$@
$$(foreach s,$$($2-sources),$$(eval $$(call add_csource,$1,$2,$$s)))
cleanfiles += $O$1lib$2.a
undefine $2-sources
endef

define add_subdir
bin :=
lib :=
subdir :=
include $1include.mk
$$(foreach b,$$(bin),$$(eval $$(call add_bin,$1,$$b)))
$$(foreach l,$$(lib),$$(eval $$(call add_lib,$1,$$l)))
$$(foreach s,$$(subdir),$$(eval $$(call add_subdir,$1$$s/)))
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
	$(foreach d,$(call reverse,$(mkdirs)),\
	  [ -d $d ] && rmdir $d || true$(\n))

print-%: ; @echo $*=$($*)
print-variables :
	@$(foreach v,$(sort $(filter-out $(print-filter),$(.VARIABLES))),\
	  $(if $(findstring $(\n),$(value $v)),\
	    $(info $v)$(info ---)$(info $(value $v))$(info ),\
	    $(info $v=$(value $v))\
	  )\
	)

.PHONY : all clean print-variables
