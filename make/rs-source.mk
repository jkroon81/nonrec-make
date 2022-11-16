$(if $(vpath-build),$(eval vpath %.rs $(top-srcdir)))

%.rlib : %.rs
	$(RUSTC_v) --crate-type rlib $< -o $@

rs-built-suffixes = b i o s

add-rust-rs-sources = $(call tflags,$1,linker) ?= $$(RUSTLD_v)

define add-rust-rs-source
$(if $(skip-deps),,-include $(builddir)/$2.d)
$(call collect-flags,$2.o,rustflags,RUSTFLAGS,$1)
$(call tflags,$1,rlibs) += $(call bpath,$2.rlib)
$(info adding)
endef
