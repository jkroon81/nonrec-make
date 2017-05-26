AS ?= $(CROSS_COMPILE)as

$(eval $(call add-vcmd,AS))

$(if $(vpath-build),$(eval vpath %.S $(top-srcdir)))

%.o : %.S
	$(AS_v) $(_$@-asflags) $< -o $@

subdir-vars      += asflags
ld-target-vars   += asflags
S-built-suffixes := b o

define add-ld-S-source
$(call collect-flags,$2.o,asflags,ASFLAGS,$1)
$(call tflags,$1,objs) += $(call bpath,$2.o)
endef
