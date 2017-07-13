VALAC ?= valac

$(eval $(call add-vcmd,VALAC,,,,...))

subdir-vars         += valaflags vala-staticlibs vala-sharedlibs
ld-target-vars      += valaflags vala-staticlibs vala-sharedlibs
vala-built-suffixes := vala.c

glib-ccflags := $(shell pkg-config gobject-2.0 --cflags)
glib-ldflags := $(shell pkg-config gobject-2.0 --libs)

%.typelib.c : %.typelib
	$(gen)cd $(dir $@) && xxd -i $(notdir $<) $(notdir $@)

.PRECIOUS : %.typelib %.typelib.c

add-symlink-if-exists = $(if $(wildcard $2),$(call add-symlink,$1,$2))

define add-ld-vala-source
$(if $(vpath-build),$(call add-symlink-if-exists,$2.vala,$(srcdir)/$2.vala))
$(call add-ld-source,$1,$2.vala,c)
endef

define add-vala-lib-deps
$(eval $(call collect-flags,$1,vala-$2libs))
$(eval $1-$2libs += $($(call tflags,$1,vala-$2libs)))
$(foreach l,$($(call tflags,$1,vala-$2libs)),$(eval \
  $(call add-vala-lib-dep,$1,$l)))
endef

define add-vala-lib-dep
$1-valaflags += --pkg=$(notdir $2) --vapidir=$(dir $2)
$1-ccflags += -I$(dir $2)
endef

define add-ld-vala-sources
$(foreach t,static shared,$(eval $(call add-vala-lib-deps,$1,$t)))
pre-targets += $(3:%=$(builddir)/%.c)
$(3:%.vala=$(builddir)/%.$(percent).c) $(builddir)/$1.%.gir \
  $(builddir)/$1.%.vapi : $(3:%.vala=$(builddir)/%.$(percent)) \
  $(addsuffix .%.vapi,$(foreach t,shared static,$(call map,ld-$tlib-filename,\
    $($(call tflags,$1,vala-$tlibs)))))
	$(q)$(foreach t,shared static,$(foreach f,\
	  $($(call tflags,$1,vala-$tlibs)),\
	  cp $(call ld-$tlib-filename,$f).vala.vapi $f.vapi &&)) true
	$$(VALAC_v) --ccode $$($(call tflags,$1,valaflags)) $(3:%=$(builddir)/%)
	$(q)$(foreach f,$(3:%.vala=$(builddir)/%),mv $f.c $f.vala.c &&) true
	$(q)if [ -e "$(builddir)/$2-$($2-girversion).gir" ]; then \
	    mv $(builddir)/$2-$($2-girversion).gir $(builddir)/$1.vala.gir; \
	fi
	$(q)if [ -e "$(builddir)/$2.vapi" ]; then \
	    mv $(builddir)/$2.vapi $(builddir)/$1.vala.vapi; \
	fi
$(eval $(call tflags,$1,ccflags-append) += $(glib-ccflags))
$(call collect-flags,$1,valaflags,VALAFLAGS)
$(call add-ld-sources,$1,$2,$(patsubst %.vala,%.c,$3),c,$4)
$(foreach t,static shared,$(eval undefine $(call tflags,$1,vala-$tlibs)))
endef

add-ld-vala-bin = $(call tflags,$1,ldflags-append) += $(glib-ldflags)

add-ld-vala-staticlib = $(call add-ld-vala-lib,$1,$2,static)

add-ld-vala-sharedlib = $(call add-ld-vala-lib,$1,$2,shared)

define add-ld-vala-lib
pre-targets += $(builddir)/$1.vala.vapi
$1-valaflags += --vapi=$(builddir)/$2.vapi \
                --header=$(builddir)/$2.h \
                --library=$2
cleanfiles += $(addprefix $2.,h vapi) $1.vala.vapi
$(if $($2-girversion),$(call add-vala-gir,$1,$2,$($2-girversion)))
$(call add-ld-vala-$3lib-$(os),$1,$2)
endef

define add-ld-vala-sharedlib-Windows_NT
$(call tflags,$1,ldflags-append) += $(glib-ldflags)
endef

define add-vala-gir
$(builddir)/$2-$3.typelib : $(builddir)/$1.vala.gir
	$(q)cp $$< $(builddir)/$2-$3.gir
	$$(gen)g-ir-compiler $(builddir)/$2-$3.gir -o $$@
$1-valaflags += --gir=$(builddir)/$2-$3.gir
cleanfiles += $(addprefix $2-$3.,gir typelib typelib.c) $1.vala.gir
$(call add-ld-source,$1,$2-$3.typelib,c)
endef
