/*
 * Paparazzi $Id: sys_time.h 3726 2009-07-18 18:22:45Z poine $
 *
 * Copyright (C) 2009 Pascal Brisset, Antoine Drouin
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

/*
 *\brief architecture independant timing functions 
 *
 */

#ifndef SYS_TIME_H
#define SYS_TIME_H

#include <inttypes.h>
#include BOARD_CONFIG

extern uint16_t cpu_time_sec;

#ifndef READYBOARD_SYS_TIME
#include "sys_time_hw.h"
#endif

#endif /* SYS_TIME_H */
