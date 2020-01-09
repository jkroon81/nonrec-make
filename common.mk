cflags := -Wall -Wextra -DNEEDED_COMMON_DEFINE
cflags-$(os) := -DNEEDED_COMMON_OS_DEFINE
asflags := --fatal-warnings
ldflags-Windows_NT := -Wl,--no-insert-timestamp
