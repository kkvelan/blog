/*
 * LAB / EDUCATION ONLY: intentionally vulnerable. Do not copy into real code.
 * Isolated VM, root-owned test machine, or similar only.
 *
 * Shows: after free(w1), w1 is dangling; malloc returns same-sized chunk for w2;
 * w1->fn() is use-after-free and dispatches through w2's function pointer -> bad().
 *
 * Build (see blog for ASan vs non-ASan):
 *   gcc -O0 -g uaf_lab_rce_demo.c -o uaf_lab_rce_demo
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static void good(void)
{
    puts("good path");
}

static void bad(void)
{
    puts("[!] UAF: stale pointer called bad() (attacker-chosen target in a real exploit).");
    fflush(stdout);
    /* RCE demo: replace process with a shell. ONLY in a throwaway environment. */
    char *argv[] = {"/bin/sh", "-i", NULL};
    char *envp[] = {NULL};
    execve("/bin/sh", argv, envp);
    perror("execve");
    _exit(127);
}

typedef struct {
    void (*fn)(void);
    unsigned id;
} Widget;

int main(void)
{
    Widget *w1 = malloc(sizeof(Widget));
    if (!w1)
        return 1;
    w1->fn = good;
    w1->id = 1;

    free(w1);

    Widget *w2 = malloc(sizeof(Widget));
    if (!w2)
        return 1;
    w2->fn = bad;
    w2->id = 2;

    /* BUG: w1 is dangling; this chunk is now w2. Call runs bad(), not good(). */
    w1->fn();

    free(w2);
    return 0;
}
