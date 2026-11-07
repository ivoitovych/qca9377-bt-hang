/* CO-36 L1 harness: fakes for the loop, timers, system and the bluez5 monitor */
/* SPDX-License-Identifier: MIT */

#ifndef CO36_HARNESS_H
#define CO36_HARNESS_H

#include <stdbool.h>
#include <stdint.h>

#include <spa/support/log.h>
#include <spa/support/loop.h>
#include <spa/support/system.h>

#include "defs.h"
#include "media-codecs.h"

#define MS(x)	((uint64_t)(x) * SPA_NSEC_PER_MSEC)

/* fakes.c: virtual time, loop, loop utils, system, log */
extern uint64_t fake_now;		/* virtual ns since test start */
extern struct spa_log fake_log;
extern struct spa_loop fake_loop;
extern struct spa_loop_utils fake_loop_utils;
extern struct spa_system fake_system;

void fakes_reset(void);
void fake_log_set_level(enum spa_log_level level);

int fake_loop_n_sources(void);
bool fake_loop_has_data(const void *data);

/* utils timer (add_timer); false if disarmed; deadline in virtual ns */
bool fake_timer_armed(struct spa_source *timer, uint64_t *deadline);
int fake_timers_live(void);		/* created and not destroyed */
int fake_timerfds_open(void);

/* fire every timer due up to `until`, earliest first (ties: armed first),
 * setting fake_now to each deadline; after() runs after each callback */
void fake_run_until(uint64_t until, void (*after)(void));

/* stubs.c: the bluez5 monitor side */
extern const struct media_codec * const stub_codecs[];
extern int stub_connect_profile_calls;
extern int stub_transports_live;

void stubs_reset(void);

#endif
