all :

O ?= build/
cleanfiles :=
default_v := 0
mkdir_p = @mkdir -p $(dir $@)

define add_cmd
$1_0 = @echo "$2 $$@";
$1_  = $$($1_$$(default_v))
$1   = $$($1_$$(V))$3
endef

$(eval $(call add_cmd,$(strip cc  ),CC  ,gcc))
$(eval $(call add_cmd,$(strip ccld),CCLD,gcc))

define add_csource
$O$1$2-$(3:.c=.o) : $1$3 Makefile
	$$(mkdir_p)
	$$(cc) -c $$< -o $$@
cleanfiles += $O$1$2-$(3:.c=.o)
endef

define add_bin
all : $O$1$2
$O$1$2 : $$(addprefix $O$1$2-,$$($2-sources:.c=.o)) Makefile
	$$(mkdir_p)
	$$(ccld) $$(addprefix $O$1$2-,$$($2-sources:.c=.o)) -o $$@
$$(foreach s,$$($2-sources),$$(eval $$(call add_csource,$1,$2,$$s)))
cleanfiles += $O$1$2
endef

define add_subdir
bin :=
subdir :=
include $1build.mk
$$(foreach b,$$(bin),$$(eval $$(call add_bin,$1,$$b)))
$$(foreach s,$$(subdir),$$(eval $$(call add_subdir,$1$$s)))
endef

$(eval $(call add_subdir,))

cleanfiles := $(strip $(cleanfiles))

clean :
	rm -f $(cleanfiles)
