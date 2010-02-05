/*
 * Paparazzi $Id: downlink.h 2689 2008-09-05 18:11:19Z rkrash $
 *  
 * Copyright (C) 2003-2006  Pascal Brisset, Antoine Drouin
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

/** \file downlink.h
 *  \brief Common code for AP and FBW telemetry
 *
 */

#ifndef DOWNLINK_H
#define DOWNLINK_H

#include <inttypes.h>

#if defined SITL

#ifdef SIM_UART
#include "sim_uart.h"
#include "pprz_transport.h"
#include "aerocomm_new.h"
#include "xbee.h"
#else /* SIM_UART */
/** Software In The Loop simulation uses IVY bus directly as the transport layer */
#include "ivy_transport.h"
#endif

#else /** SITL */
#include "pprz_transport.h"
#include "modem.h"
#include "aerocomm_new.h"
#include "xbee.h"
#endif /** !SITL */

#ifdef AP
/** Telemetry mode for AP process: index in the telemetry.xml file */
extern uint8_t telemetry_mode_Ap;
#endif

#ifdef FBW
/** Telemetry mode for FBW process: index in the telemetry.xml file */
extern uint8_t telemetry_mode_Fbw;
#endif

/** Counter of messages not sent because of unavailibity of the output buffer*/
extern uint8_t downlink_nb_ovrn;

#define __Transport(dev, _x) dev##_x
#define _Transport(dev, _x) __Transport(dev, _x)
#define Transport(_x) _Transport(DOWNLINK_TRANSPORT, _x)


/** Set of macros for generated code (messages.h) from messages.xml */
#define DownlinkSizeOf(_x) Transport(SizeOf(_x))

#define DownlinkCheckFreeSpace(_x) Transport(CheckFreeSpace((uint8_t)(_x)))

#define DownlinkPutUint8(_x) Transport(PutUint8(_x))

#define DownlinkPutInt8ByAddr(_x) Transport(PutInt8ByAddr(_x))
#define DownlinkPutUint8ByAddr(_x) Transport(PutUint8ByAddr(_x))
#define DownlinkPutInt16ByAddr(_x) Transport(PutInt16ByAddr(_x))
#define DownlinkPutUint16ByAddr(_x) Transport(PutUint16ByAddr(_x))
#define DownlinkPutInt32ByAddr(_x) Transport(PutInt32ByAddr(_x))
#define DownlinkPutUint32ByAddr(_x) Transport(PutUint32ByAddr(_x))
#define DownlinkPutFloatByAddr(_x) Transport(PutFloatByAddr(_x))

#define DownlinkPutFloatArray(_n, _x) Transport(PutFloatArray(_n, _x))
#define DownlinkPutInt16Array(_n, _x) Transport(PutInt16Array(_n, _x))
#define DownlinkPutUint16Array(_n, _x) Transport(PutUint16Array(_n, _x))
#define DownlinkPutUint8Array(_n, _x) Transport(PutUint8Array(_n, _x))

#define DonwlinkOverrun() downlink_nb_ovrn++;

#define DownlinkStartMessage(_name, msg_id, payload_len) { \
  Transport(Header(payload_len)); \
  Transport(PutUint8(AC_ID)); \
  Transport(PutNamedUint8(_name, msg_id)); \
}

#define DownlinkEndMessage() Transport(Trailer())

#endif /* DOWNLINK_H */
