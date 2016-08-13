print-filter := $(.VARIABLES) print-filter \n

O ?= build

cleanfiles :=
mkdirs :=
default_v := 0

tvar = $(patsubst ./%,%,$(builddir)/$1)
first = $(firstword $1)
rest = $(wordlist 2,$(words $1),$1)
reverse = $(strip $(if $1,$(call reverse,$(call rest,$1)) $(call first,$1)))
trim-end = $(if $(filter %$1,$2),$(call trim-end,$1,$(patsubst %$1,%,$2)),$2)
libs = $(call normpath,$($1-libs))
normpath = $(patsubst $(CURDIR)/%,%,$(abspath $1))
objs = $(addprefix $(builddir)/$1-,$($1-sources:.c=.o))

o := $(call trim-end,/,$O)

define \n


endef

define add_cmd
$1_0 = @echo "$2 $$(patsubst $o/%,%,$3)";
$1_  = $$($1_$(default_v))
$1   = $$($1_$(V))$4
endef

q_0 = @
q_  = $(q_$(default_v))
q   = $(q_$(V))

$(eval $(call add_cmd,$(strip ar    ),AR    ,$$@  ,ar))
$(eval $(call add_cmd,$(strip ranlib),RANLIB,$$@  ,ranlib))
$(eval $(call add_cmd,$(strip cc    ),CC    ,$$*.o,gcc))
$(eval $(call add_cmd,$(strip ccld  ),CCLD  ,$$@  ,gcc))

%.a :
	$(q)rm -f $@
	$(ar) cru $@ $($@-objs)
	$(ranlib) $@

%.d %.o :
	$(cc) $($*.o-ccflags) -MMD -MP -c $($*.o-csource) -o $*.o

define add_csource
mkdirs := $$(sort $$(mkdirs) $$(builddir))
$$(eval $$(call tvar,$1-$(2:.c=.o))-csource := $$(srcdir)/$2)
$$(eval $$(call tvar,$1-$(2:.c=.o))-ccflags := $$($1-ccflags))
$$(builddir)/$1-$(2:.c=.o) : Makefile $$(srcdir)/include.mk | $$(builddir)
-include $$(builddir)/$1-$(2:.c=.d)
cleanfiles += $$(builddir)/$1-$(2:.c=.o) $$(builddir)/$1-$(2:.c=.d)
endef

define add_bin
mkdirs := $$(sort $$(mkdirs) $$(builddir))
$$(eval $$(call tvar,$1)-objs := $$(call objs,$1))
$$(eval $$(call tvar,$1)-libs := $$(call libs,$1))
all : $$(builddir)/$1
$$(builddir)/$1 : $$($$(call tvar,$1)-objs) \
                  $$($$(call tvar,$1)-libs) \
                  Makefile \
                  $$(srcdir)/include.mk \
                  | $$(builddir)
	$$(ccld) $$($$@-objs) $$($$@-libs) -o $$@
$$(foreach s,$$($1-sources),$$(eval $$(call add_csource,$1,$$s)))
cleanfiles += $$(builddir)/$1
undefine $1-sources
undefine $1-ccflags
undefine $1-libs
endef

define add_lib
mkdirs := $$(sort $$(mkdirs) $$(builddir))
$$(eval $$(call tvar,lib$1.a)-objs := $$(call objs,$1))
all : $$(builddir)/lib$1.a
$$(builddir)/lib$1.a : $$($$(call tvar,lib$1.a)-objs) \
                       Makefile \
                       $$(srcdir)/include.mk \
                       | $$(builddir)
$$(foreach s,$$($1-sources),$$(eval $$(call add_csource,$1,$$s)))
cleanfiles += $$(builddir)/lib$1.a
undefine $1-sources
endef

define add_subdir
srcdir := $$(if $1,$1,.)
builddir := $$(if $o,$o,.)$$(if $1,/$1)
bin :=
lib :=
subdir :=
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
	$(if $o,$(foreach d,$(call reverse,$(mkdirs)),\
	  [ -d $d ] && rmdir $d || true$(\n)))

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

.PHONY : all clean print-variables
