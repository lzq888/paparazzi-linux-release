/*
 * $Id: rc_settings.c 1725 2007-08-26 14:39:46Z hecto $
 * Flight-time calibration facility
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


#include <inttypes.h>
#include "rc_settings.h"
#include "radio.h"
#include "autopilot.h"
#include "infrared.h"
#include "nav.h"
#include "estimator.h"
#include "inter_mcu.h"
#include "fw_h_ctl.h"


#define ParamValInt16(param_init_val, param_travel, cur_pulse, init_pulse) \
(param_init_val + (int16_t)(((float)(cur_pulse - init_pulse)) * param_travel / (float)MAX_PPRZ))

#define ParamValFloat(param_init_val, param_travel, cur_pulse, init_pulse) \
(param_init_val + ((float)(cur_pulse - init_pulse)) * param_travel / (float)MAX_PPRZ)

#define RcChannel(x) (fbw_state->channels[x])

/** Includes generated code from tuning_rc.xml */
#include "settings.h"


void rc_settings(bool_t mode_changed __attribute__ ((unused))) {
  RCSettings(mode_changed);
}