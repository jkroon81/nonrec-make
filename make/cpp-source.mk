CXX = $(CROSS_COMPILE)g++

$(eval $(call add-vcmd,CXX))
$(eval $(call add-vcmd,CXXLD,,$$(CXX)))
$(eval $(call add-vcmd,CXXAS,,$$(CXX)))
$(eval $(call add-vcmd,CXXPP,,$$(CXX)))

$(if $(vpath-build),$(eval vpath %.cpp $(top-srcdir)))

%.o : %.cpp
	$(CXX_v) -c -MMD -MP $(_$@-cxxflags) $< -o $@
%.s : %.cpp
	$(CXXAS_v) -S $(_$*.o-cxxflags) $< -o $@
%.i : %.cpp
	$(CXXPP_v) -E -P $(_$*.o-cxxflags) $< -o $@

subdir-vars       += cxxflags
ld-target-vars    += cxxflags
cpp-built-suffixes = b i o s
cpp-extra-suffixes = d

i-dep = cpp
s-dep = asm

.PHONY : asm cpp

add-ld-cpp-sources = $(call tflags,$1,linker) = $$(CXXLD_v)

define add-ld-cpp-source
$(if $(skip-deps),,-include $(builddir)/$2.d)
$(call collect-flags,$2.o,cxxflags,CXXFLAGS,$1)
$(call tflags,$1,objs) += $(call bpath,$2.o)
$(call bpath,$2.i) $(call bpath,$2.s) : $(call bpath,$2.o)
endef

add-ld-cpp-sharedlib = $(call tflags,$1,cxxflags-append) += -fpic
