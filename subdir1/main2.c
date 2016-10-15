#ifndef NEEDED_DEFINE
#error need define
#endif

#include <stdio.h>
#include <foo.h>

int main(void)
{
  printf("Another World %d!\n", test_func(4,5));
  return 0;
}
