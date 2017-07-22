VALAC ?= valac

$(eval $(call add-vcmd,VALAC))

subdir-vars         += valaflags vala-staticlibs vala-sharedlibs
ld-target-vars      += valaflags vala-staticlibs vala-sharedlibs
vala-built-suffixes := c

glib-ccflags := $(shell pkg-config gobject-2.0 --cflags)
glib-ldflags := $(shell pkg-config gobject-2.0 --libs)

%.fast-vapi : %.vala
	$(VALAC_v) --fast-vapi=$@ $<
%.typelib : %.gir
	$(gen)g-ir-compiler $< -o $@
%.typelib.c : %.typelib
	$(gen)cd $(dir $@) && xxd -i $(notdir $<) $(notdir $@)

.PRECIOUS : %.typelib %.typelib.c

add-symlink-if-exists = $(if $(wildcard $2),$(call add-symlink,$1,$2))

define add-ld-vala-source
$(if $(vpath-build),$(call add-symlink-if-exists,$2.vala,$(srcdir)/$2.vala))
$(call add-ld-source,$1,$2,c)
$(builddir)/$2.c : $(builddir)/$2.vala $($(call tflags,$1,fast-vapi))
	$$(VALAC_v) --ccode --deps=$(builddir)/$2.vala.d \
	  $$($(call tflags,$1,valaflags)) \
	  $($(call tflags,$1,fast-vapi):%=--use-fast-vapi=%) \
	  $(builddir)/$2.vala
cleanfiles += $2.fast-vapi $2.vala.d
-include $(builddir)/$2.vala.d
endef

define add-vala-lib-deps
$(eval $(call collect-flags,$1,vala-$2libs))
$(eval $1-$2libs += $($(call tflags,$1,vala-$2libs)))
$(foreach l,$($(call tflags,$1,vala-$2libs)),$(eval \
  $(call add-vala-lib-dep,$1,$(call relpath,$l))))
endef

define add-vala-lib-dep
$1-valaflags += --pkg=$(notdir $2) --vapidir=$(dir $2)
$1-ccflags += -I$(dir $2)
endef

define add-ld-vala-sources
$(foreach t,static shared,$(eval $(call add-vala-lib-deps,$1,$t)))
$(eval $(call tflags,$1,fast-vapi) := $(builddir)/$(3:%.vala=%.fast-vapi))
$(eval $(call tflags,$1,ccflags-append) += $(glib-ccflags))
$(call collect-flags,$1,valaflags,VALAFLAGS)
$(call add-ld-sources,$1,$2,$(patsubst %.vala,%.c,$3),c,$4)
$(foreach t,static shared,$(eval undefine $(call tflags,$1,vala-$tlibs)))
endef

add-ld-vala-bin = $(call tflags,$1,ldflags-append) += $(glib-ldflags)

add-ld-vala-staticlib = $(call add-ld-vala-lib,$1,$2,static)

add-ld-vala-sharedlib = $(call add-ld-vala-lib,$1,$2,shared)

define add-ld-vala-lib
$1-valaflags += --vapi=$(builddir)/$2.vapi \
                --header=$(builddir)/$2.h \
                --library=$2
cleanfiles += $(addprefix $2.,h vapi)
$(if $($2-girversion),$(call add-vala-gir,$1,$2,$($2-girversion)))
undefine $2-girversion
$(call add-ld-vala-$3lib-$(os),$1,$2)
endef

define add-ld-vala-sharedlib-Windows_NT
$(call tflags,$1,ldflags-append) += $(glib-ldflags)
endef

define add-vala-gir
$1-valaflags += --gir=$(builddir)/$2-$3.gir
cleanfiles += $(addprefix $2-$3.,gir typelib typelib.c)
$(call add-ld-source,$1,$2-$3.typelib,c)
endef
