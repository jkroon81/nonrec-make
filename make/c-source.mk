CC ?= $(CROSS_COMPILE)gcc

$(eval $(call add-vcmd,CC))
$(eval $(call add-vcmd,CCAS,,$$(CC)))
$(eval $(call add-vcmd,CPP,,$$(CC)))

$(if $(vpath-build),$(eval vpath %.c $(top-srcdir)))

%.o : %.c
	$(CC_v) -c -MMD -MP $(_$@-ccflags) $< -o $@
%.s : %.c
	$(CCAS_v) -S $(_$*.o-ccflags) $< -o $@
%.i : %.c
	$(CPP_v) -E $(_$*.o-ccflags) $< -o $@

subdir-vars      += ccflags
ld-target-vars   += ccflags
c-built-suffixes := b i o s
c-extra-suffixes := d

i-dep := cpp
s-dep := asm

.PHONY : asm cpp

define add-ld-c-source
$(if $(skip-deps),,-include $(builddir)/$2.d)
$(call collect-flags,$2.o,ccflags,CFLAGS,$1)
$(call tflags,$1,objs) += $(call bpath,$2.o)
endef
