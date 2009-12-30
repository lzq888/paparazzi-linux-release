/*  $Id: inter_mcu.h 4113 2009-09-08 20:09:39Z hecto $
 *
 * Copyright (C) 2003-2005  Pascal Brisset, Antoine Drouin
 *
 * This file is part of paparazzi.
 *
 * paparazzi is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * paparazzi is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with paparazzi; see the file COPYING.  If not, write to
 * the Free Software Foundation, 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.  
 *
 */

/** \brief Communication between fbw and ap processes
 * This unit contains the data structure used to communicate between the
 * "fly by wire" process and the "autopilot" process. It must be linked once in a
 * monoprocessor architecture, twice in a twin-processors (the historical
 * Atmel AVRs mega8-mega128 one) architecture. In the latter case, the
 * inter-mcu communication process (e.g. SPI) must fill and read these data structures.
*/

#ifndef INTER_MCU_H
#define INTER_MCU_H


#ifdef INTER_MCU

#include <inttypes.h>

#include "std.h"
#if defined RADIO_CONTROL || RADIO_CONTROL_AUTO1
#include "radio.h"
#endif

#include "paparazzi.h"
#include "airframe.h"
#include "radio_control.h"
#include "main_fbw.h"

/** Data structure shared by fbw and ap processes */
struct fbw_state {
#if defined RADIO_CONTROL || RADIO_CONTROL_AUTO1
  pprz_t channels[RADIO_CTL_NB];  
  uint8_t ppm_cpt;
#endif
  uint8_t status;
  uint8_t nb_err;
  uint8_t vsupply; 	/* 1e-1 V */
  int16_t current;	/* milliAmps */
};

struct ap_state {
  pprz_t commands[COMMANDS_NB];  
};

// Status bits from FBW to AUTOPILOT
#define STATUS_RADIO_OK 0
#define STATUS_RADIO_REALLY_LOST 1
#define STATUS_MODE_AUTO 2
#define STATUS_MODE_FAILSAFE 3
#define AVERAGED_CHANNELS_SENT 4
#define MASK_FBW_CHANGED 0xf


extern struct fbw_state* fbw_state;
extern struct ap_state*  ap_state;

extern volatile bool_t inter_mcu_received_fbw;
extern volatile bool_t inter_mcu_received_ap;


#ifdef FBW

extern uint8_t time_since_last_ap;
extern bool_t ap_ok;

#define AP_STALLED_TIME        30  // 500ms with a 60Hz timer


static inline void inter_mcu_init(void) {
  fbw_state->status = 0;
  fbw_state->nb_err = 0;

  ap_ok = FALSE;
}


/* Prepare data to be sent to mcu0 */
static inline void inter_mcu_fill_fbw_state (void) {
  uint8_t status = 0;

#ifdef RADIO_CONTROL
  uint8_t i;
  for(i = 0; i < RADIO_CTL_NB; i++)
    fbw_state->channels[i] = rc_values[i];

  fbw_state->ppm_cpt = last_ppm_cpt;

  status = (rc_status == RC_OK ? _BV(STATUS_RADIO_OK) : 0);
  status |= (rc_status == RC_REALLY_LOST ? _BV(STATUS_RADIO_REALLY_LOST) : 0);
#endif // RADIO_CONTROL

  status |= (fbw_mode == FBW_MODE_AUTO ? _BV(STATUS_MODE_AUTO) : 0);
  status |= (fbw_mode == FBW_MODE_FAILSAFE ? _BV(STATUS_MODE_FAILSAFE) : 0);
  fbw_state->status  = status;

#ifdef RADIO_CONTROL
  if (rc_values_contains_avg_channels) {
    fbw_state->status |= _BV(AVERAGED_CHANNELS_SENT);
    rc_values_contains_avg_channels = FALSE;
  }
#endif // RADIO_CONTROL

  fbw_state->vsupply = fbw_vsupply_decivolt;
  fbw_state->current = fbw_current_milliamp;
}

/** Prepares date for next comm with AP. Set ::ap_ok to TRUE */
static inline void inter_mcu_event_task( void) {
  time_since_last_ap = 0;
  ap_ok = TRUE;
#if defined SINGLE_MCU
  /**Directly set the flag indicating to AP that shared buffer is available*/
  inter_mcu_received_fbw = TRUE;
#endif
}

/** Monitors AP. Set ::ap_ok to false if AP is down for a long time. */
static inline void inter_mcu_periodic_task(void) {
  if (time_since_last_ap >= AP_STALLED_TIME) {
    ap_ok = FALSE;
  } else
    time_since_last_ap++;
}

#endif /* FBW */

#endif /* INTER_MCU */

#endif /* INTER_MCU_H */
