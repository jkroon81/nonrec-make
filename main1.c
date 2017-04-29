#ifndef NEEDED_DEFINE
#error need define
#endif

#include <stdio.h>
#include <glib.h>
#include <test1.h>

int main(void)
{
  printf("Hello %s, using GLib %u.%u!\n",
         SNAKE,
         glib_major_version,
         glib_minor_version);
  return 0;
}
