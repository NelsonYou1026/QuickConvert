#include <errno.h>
#include <stdio.h>
#include <sys/resource.h>

/* Test-only native child: report its own priority without launching another process. */
int main(int argc, char **argv) {
    if (argc != 2) return 2;
    errno = 0;
    int priority = getpriority(PRIO_PROCESS, 0);
    if (errno != 0) return 3;
    FILE *output = fopen(argv[1], "w");
    if (!output) return 4;
    int written = fprintf(output, "%d\n", priority);
    int closed = fclose(output);
    return written < 0 || closed != 0;
}
