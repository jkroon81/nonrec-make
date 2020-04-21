#include <assert.h>
#include <dirent.h>
#include <stdio.h>
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
                }
                strcat(subdir, dir->d_name);
                strcat(subdir, " ");
            }
        }
    }
    return subdir;
}

int nrmake_gmk_setup(void)
{
    gmk_add_function("nrmake_subdir", nrmake_subdir, 1, 1, 0);
    return 1;
}
