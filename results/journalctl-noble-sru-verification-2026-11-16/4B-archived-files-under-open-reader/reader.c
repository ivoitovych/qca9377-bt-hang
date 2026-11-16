/* reader.c : read a journal directory through the sd-journal API, one line per entry, slowly.
 *   reader DIR forward|backward [ASSUME_IMMUTABLE]
 * The journal is opened with flags 0 (inotify active: sd_journal_get_fd() is called) unless the third argument is
 * given. sd_journal_process() is called every 100 entries, so that files removed from the directory are noticed.
 * Output: "MSG <MESSAGE value>" per entry; on a failure "ERR <negative errno>" and exit status 2. */
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <systemd/sd-journal.h>

int main(int argc, char **argv) {
        sd_journal *j;
        int r, backward, n = 0;
        const void *d;
        size_t l;

        if (argc < 3)
                return 64;
        backward = !strcmp(argv[2], "backward");
        r = sd_journal_open_directory(&j, argv[1], 0);
        if (r < 0) {
                printf("ERR %d open\n", r);
                return 2;
        }
        sd_journal_get_fd(j);
        if (backward)
                sd_journal_seek_tail(j);
        else
                sd_journal_seek_head(j);
        setvbuf(stdout, NULL, _IOLBF, 0);
        for (;;) {
                r = backward ? sd_journal_previous(j) : sd_journal_next(j);
                if (r < 0) {
                        printf("ERR %d next\n", r);
                        return 2;
                }
                if (r == 0)
                        break;
                r = sd_journal_get_data(j, "MESSAGE", &d, &l);
                if (r < 0) {
                        printf("ERR %d get_data\n", r);
                        return 2;
                }
                printf("MSG %.*s\n", (int) l - 8, (const char *) d + 8);
                if (++n % 100 == 0) {
                        usleep(10000);
                        r = sd_journal_process(j);
                        if (r < 0) {
                                printf("ERR %d process\n", r);
                                return 2;
                        }
                }
        }
        sd_journal_close(j);
        return 0;
}
