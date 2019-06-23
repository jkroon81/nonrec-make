#if !defined(NEEDED_COMMON_DEFINE) || !defined(NEEDED_COMMON_OS_DEFINE)
#error need define
#endif

#include "foo.h"

int test_func(int x, int y)
{
  return x + y;
}
