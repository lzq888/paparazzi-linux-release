/*
 * Paparazzi $Id: radio_control.c 1045 2006-07-11 22:02:09Z hecto $
 *  
 * Copyright (C) 2006 Pascal Brisset, Antoine Drouin
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

#include "radio_control.h"

pprz_t rc_values[PPM_NB_PULSES];
uint8_t rc_status;
int32_t avg_rc_values[PPM_NB_PULSES];
uint8_t rc_values_contains_avg_channels = FALSE;
uint8_t time_since_last_ppm;
uint8_t ppm_cpt, last_ppm_cpt;

