ccflags := -Wall -Wextra -DNEEDED_COMMON_DEFINE
ccflags-$(os) := -DNEEDED_COMMON_OS_DEFINE
asflags := --fatal-warnings
ldflags-Windows_NT := -Wl,--no-insert-timestamp
