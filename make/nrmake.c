#include <assert.h>
#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <gnumake.h>

int plugin_is_GPL_compatible;

static char* nrmake_subdir(const char *name, unsigned int argc, char **argv)
{
    DIR *d;
    struct dirent *dir;
    d = opendir(argv[0]);
    assert(d != NULL);
    char *subdir = NULL;
    char *tail = NULL;
    while((dir = readdir(d)) != NULL) {
        if (dir->d_type == DT_DIR) {
            if (strcmp(dir->d_name, ".") == 0 ||
                strcmp(dir->d_name, "..") == 0)
                continue;
            char path[256];
            snprintf(path, sizeof(path), "%s/%s/Makefile", argv[0], dir->d_name);
            struct stat buf;
            int rv = stat(path, &buf);
            if (rv == 0 && (buf.st_mode & S_IFMT) == S_IFREG) {
                if (subdir == NULL) {
                    subdir = gmk_alloc(1024);
                    memset(subdir, 0, 1024);
                    tail = subdir;
                }
                size_t len = strlen(dir->d_name);
                memcpy(tail, dir->d_name, len);
                tail += len;
                *tail = ' ';
                tail++;
                *tail = '\0';
            }
        }
    }
    return subdir;
}

static char* nrmake_clearenv(const char *name, unsigned int argc, char **argv)
{
    extern char **environ;
    for(char **p = environ; *p != NULL; p++) {
        char var[256];
        char *end = strchr(*p, '=');
        int nchar = end - *p;
        memcpy(var, *p, nchar);
        var[nchar] = '\0';
        int undef = 1;
        for(int i = 0; i < argc; i++)
            if (strcmp(var, argv[i]) == 0) {
                undef = 0;
                break;
            }
        if (undef) {
            char cmd[256];
            snprintf(cmd, sizeof(cmd), "unexport %s", var);
            gmk_eval(cmd, NULL);
        }
    }
    return NULL;
}

int nrmake_gmk_setup(void)
{
    gmk_add_function("nrmake_subdir", nrmake_subdir, 1, 1, 0);
    gmk_add_function("nrmake_clearenv", nrmake_clearenv, 0, 255, 0);
    return 1;
}
