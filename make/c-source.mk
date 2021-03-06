CC ?= $(CROSS_COMPILE)gcc

$(eval $(call add-vcmd,CC))
$(eval $(call add-vcmd,CCLD,,$$(CC)))
$(eval $(call add-vcmd,CCAS,,$$(CC)))
$(eval $(call add-vcmd,CPP,,$$(CC)))

$(if $(vpath-build),$(eval vpath %.c $(top-srcdir)))

%.o : %.c
	$(CC_v) -c -MMD -MP $(_$@-cflags) $< -o $@
%.s : %.c
	$(CCAS_v) -S $(_$*.o-cflags) $< -o $@
%.i : %.c
	$(CPP_v) -E -P $(_$*.o-cflags) $< -o $@

subdir-vars     += cflags
ld-target-vars  += cflags
c-built-suffixes = b i o s
c-extra-suffixes = d

i-dep = cpp
s-dep = asm

.PHONY : asm cpp

add-ld-c-sources = $(call tflags,$1,linker) ?= $$(CCLD_v)

define add-ld-c-source
$(if $(skip-deps),,-include $(builddir)/$2.d)
$(call collect-flags,$2.o,cflags,CFLAGS,$1)
$(call tflags,$1,objs) += $(call bpath,$2.o)
endef

add-ld-c-sharedlib = $(call tflags,$1,cflags-append) += -fpic
