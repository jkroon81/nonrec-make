VALAC ?= valac

$(eval $(call add-vcmd,VALAC,,,$$(@:%.vala-stamp=%)))

subdir-vars         += valaflags vala-staticlibs vala-sharedlibs
ld-target-vars      += valaflags vala-staticlibs vala-sharedlibs
vala-built-suffixes := c

gobject-cflags  := $(shell pkg-config gobject-2.0 --cflags)
gobject-ldflags := $(shell pkg-config gobject-2.0 --libs)

%.typelib : %.gir
	$(gen)g-ir-compiler $< -o $@

%.typelib.c : %.typelib
	$(gen)cd $(dir $@) && xxd -i $(notdir $<) $(notdir $@)

.PRECIOUS : %.typelib %.typelib.c

add-symlink-if-exists = $(if $(wildcard $2),$(call add-symlink,$1,$2))

define add-ld-vala-source
$(if $(vpath-build),$(call add-symlink-if-exists,$2.vala,$(srcdir)/$2.vala))
$(builddir)/$2.c : $(builddir)/$1.vala-stamp
$(call add-ld-source,$1,$2,c)
endef

define add-vala-lib-deps
$(eval $(call collect-flags,$1,vala-$2libs))
$(eval $1-$2libs += $($(call tflags,$1,vala-$2libs)))
$(foreach l,$($(call tflags,$1,vala-$2libs)),$(eval $(call add-vala-lib-dep
  ,$1,$(call ld-$2lib-filename,$l),$(notdir $l))))
undefine $(call tflags,$1,vala-$2libs)
endef

define add-vala-lib-dep
$1-valaflags += --pkg=$3 --vapidir=$(dir $2)
$1-cflags += -I$(dir $2)
$(builddir)/$1.vala-stamp : $2.vala-stamp
endef

define add-ld-vala-sources
$(builddir)/$1.vala-stamp : $(3:%=$(builddir)/%) $(makefile-deps)
	$$(VALAC_v) --ccode $$($(call tflags,$1,valaflags)) $(3:%=$(builddir)/%)
	$(q)touch $$@
cleanfiles += $1.vala-stamp
$(foreach t,static shared,$(eval $(call add-vala-lib-deps,$1,$t)))
$(eval $(call tflags,$1,cflags-append) += $(gobject-cflags))
$(call collect-flags,$1,valaflags,VALAFLAGS)
$(call add-ld-sources,$1,$2,$(patsubst %.vala,%.c,$3),c,$4)
endef

add-ld-vala-bin = $(call tflags,$1,ldflags-append) += $(gobject-ldflags)

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
$(call tflags,$1,ldflags-append) += $(gobject-ldflags)
endef

define add-vala-gir
$(builddir)/$2-$3.gir : $(builddir)/$1.vala-stamp
$1-valaflags += --gir=$(builddir)/$2-$3.gir
cleanfiles += $(addprefix $2-$3.,gir typelib typelib.c)
$(call add-ld-source,$1,$2-$3.typelib,c)
endef
