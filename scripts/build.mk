cc   := gcc
ccld := gcc

cleanfiles :=

define add_csource
$1-$(2:.c=.o) : $2
	$(cc) -c $$< -o $$@
cleanfiles += $1-$(2:.c=.o)
endef

define add_bin
$1 : $$(addprefix $1-,$$($1-sources:.c=.o))
	$(ccld) $$+ -o $$@
$$(foreach s,$$($1-sources),$$(eval $$(call add_csource,$1,$$s)))
cleanfiles += $1
endef

define add_subdir
bin :=
include $1/build
$$(foreach b,$$(bin),$$(eval $$(call add_bin,$$b)))
endef

$(eval $(call add_subdir,.))

clean :
	rm -f $(cleanfiles)
