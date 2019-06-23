#if !defined(NEEDED_COMMON_DEFINE) || !defined(NEEDED_COMMON_OS_DEFINE)
#error need define
#endif

#include <stdio.h>

void tickle(void)
{
  printf("Tickle\n");
}
