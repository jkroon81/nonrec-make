all :

O ?= build/
cleanfiles :=
dirs :=
default_v := 0

define add_cmd
$1_0 = @echo "$2 $$@";
$1_  = $$($1_$$(default_v))
$1   = $$($1_$$(V))$3
endef

define add_silent_cmd
$1_0 = @
$1_  = $$($1_$$(default_v))
$1   = $$($1_$$(V))$2
endef

$(eval $(call add_cmd,$(strip cc  ),CC  ,gcc))
$(eval $(call add_cmd,$(strip ccld),CCLD,gcc))
$(eval $(call add_silent_cmd,mkdir_p,mkdir -p))

define add_csource
dirs := $(sort $(dirs) $O$1)
$O$1$2-$(3:.c=.o) : $1$3 Makefile | $O$1
	$$(cc) $$($2-ccflags) -MMD -MP -c $$< -o $$@
-include $O$1$2-$(3:.c=.d)
cleanfiles += $O$1$2-$(3:.c=.o) $O$1$2-$(3:.c=.d)
endef

define add_bin
dirs := $(sort $(dirs) $O$1)
all : $O$1$2
$O$1$2 : $$(addprefix $O$1$2-,$$($2-sources:.c=.o)) Makefile | $O$1
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

$(dirs) :
	$(mkdir_p) $@

cleanfiles := $(strip $(cleanfiles))

clean :
	rm -f $(cleanfiles)
	for d in $(dirs); do \
	    if [ -d $$d ]; then \
	        rmdir --ignore-fail-on-non-empty -p $$d; \
	    fi \
	done
