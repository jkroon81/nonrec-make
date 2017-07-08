VALAC ?= valac

$(eval $(call add-vcmd,VALAC,,,$$(@:%.vala-stamp=%)))

subdir-vars         += valaflags vala-staticlibs vala-sharedlibs
ld-target-vars      += valaflags vala-staticlibs vala-sharedlibs
vala-built-suffixes := c

glib-ccflags := $(shell pkg-config gobject-2.0 --cflags)
glib-ldflags := $(shell pkg-config gobject-2.0 --libs)

%.typelib : %.gir
	$(gen)g-ir-compiler $< -o $@

%.typelib.c : %.typelib
	$(gen)cd $(dir $@) && xxd -i $(notdir $<) $(notdir $@)

.PRECIOUS : %.typelib %.typelib.c

add-symlink-if-exists = $(if $(wildcard $2),$(call add-symlink,$1,$2))

define add-ld-vala-source
$(if $(vpath-build),$(call add-symlink-if-exists,$2.vala,$(srcdir)/$2.vala))
$(builddir)/$2.c : $(builddir)/$1.vala-stamp
	@true
$(call add-ld-source,$1,$2,c)
endef

define add-vala-libs
$(eval $(call collect-flags,$1,vala-$2libs))
$(foreach l,$($(call tflags,$1,vala-$2libs)),$(eval $(call add-vala-lib-dep
  ,$1,$(call ld-$2lib-filename,$l),$(call ld-$2lib-shortname,$l),$2)))
undefine $(call tflags,$1,vala-$2libs)
endef

define add-vala-lib-dep
$1-valaflags += --pkg=$3 --vapidir=$(dir $2)
$1-ccflags += -I$(dir $2)
$1-$4libs += $2
$(builddir)/$1.vala-stamp : $2.vala-stamp
endef

define add-ld-vala-sources
$(builddir)/$1.vala-stamp : $(addprefix $(builddir)/,$2) $(makefile-deps)
	$$(VALAC_v) --ccode $$(_$$(@:.vala-stamp=)-valaflags) \
	  $(addprefix $(builddir)/,$2)
	$(q)touch $$@
cleanfiles += $1.vala-stamp
$(foreach t,static shared,$(eval $(call add-vala-libs,$1,$t)))
$(eval $(call tflags,$1,ccflags-append) += $(glib-ccflags))
$(call collect-flags,$1,valaflags,VALAFLAGS)
$(call add-ld-sources,$1,$(patsubst %.vala,%.c,$2),c,$3)
endef

add-ld-vala-bin = $(call tflags,$1,ldflags-append) += $(glib-ldflags)

add-ld-vala-staticlib = $(call add-ld-vala-lib \
  ,$1,$(call ld-staticlib-shortname,$1),static)

add-ld-vala-sharedlib = $(call add-ld-vala-lib \
  ,$1,$(call ld-sharedlib-shortname,$1),shared)

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
$(builddir)/$2-$3.gir : $(builddir)/$1.vala-stamp
	@true
$1-valaflags += --gir=$(builddir)/$2-$3.gir
cleanfiles += $(addprefix $2-$3.,gir typelib typelib.c)
$(call add-ld-source,$1,$2-$3.typelib,c)
endef
