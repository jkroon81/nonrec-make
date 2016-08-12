all :

cleanfiles :=
default_v := 0

define add_cmd
$1_0 = @echo "$2 $$@";
$1_  = $$($1_$$(default_v))
$1   = $$($1_$$(V))$3
endef

$(eval $(call add_cmd,$(strip cc  ),CC  ,gcc))
$(eval $(call add_cmd,$(strip ccld),CCLD,gcc))

define add_csource
$1$2-$(3:.c=.o) : $1$3
	$$(cc) -c $$< -o $$@
cleanfiles += $1$2-$(3:.c=.o)
endef

define add_bin
all : $1$2
$1$2 : $$(addprefix $1$2-,$$($2-sources:.c=.o))
	$$(ccld) $$+ -o $$@
$$(foreach s,$$($2-sources),$$(eval $$(call add_csource,$1,$2,$$s)))
cleanfiles += $1$2
endef

define add_subdir
bin :=
subdir :=
include $1build
$$(foreach b,$$(bin),$$(eval $$(call add_bin,$1,$$b)))
$$(foreach s,$$(subdir),$$(eval $$(call add_subdir,$1$$s)))
endef

$(eval $(call add_subdir,))

cleanfiles := $(strip $(cleanfiles))

clean :
	rm -f $(cleanfiles)
