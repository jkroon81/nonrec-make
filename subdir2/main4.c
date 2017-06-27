#ifndef NEEDED_DEFINE
#error need define
#endif

#include <stdio.h>

extern void shared_function(void);

int main(void)
{
  printf("Test 4!\n");
  shared_function();
  return 0;
}
