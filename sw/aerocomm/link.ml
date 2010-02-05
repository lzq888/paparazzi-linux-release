(*
 * $Id: link.ml 2689 2008-09-05 18:11:19Z rkrash $
 *
 * Copyright (C) 2004 CENA/ENAC, Pascal Brisset, Antoine Drouin
 * Aerocomm device and protocol added by Roman Krashanitsa UofA 2008
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
 *)

open Latlong
open Printf
module W = Wavecard
module Tm_Pprz = Pprz.Messages(struct let name = "telemetry" end)
module Ground_Pprz = Pprz.Messages(struct let name = "ground" end)
module Dl_Pprz = Pprz.Messages(struct let name = "datalink" end)
module PprzTransport = Serial.Transport(Pprz.Transport)

type transport =
    Modem
  | Pprz
  | Wavecard
  | XBee
  | Aerocomm
  | Aerocomm_ver2

type ground_device = {
    fd : Unix.file_descr; transport : transport ; baud_rate : int
  }

type airborne_device = 
    WavecardDevice of W.addr
  | XBeeDevice
  | AerocommDevice
  | AerocommDevice_ver2
  | Uart (** For HITL for example *)

let my_id = 0

let ios = int_of_string
let (//) = Filename.concat
let conf = Env.paparazzi_home // "conf"

let airborne_device = fun device addr ->
  match device with
    "WAVECARD" -> WavecardDevice (W.addr_of_string addr)
  | "XBEE" -> XBeeDevice
  | "AEROCOMM" -> AerocommDevice
  | "AEROCOMM__" -> AerocommDevice_ver2
  | "PPRZ" -> Uart
  | _ -> failwith (sprintf "Link: unknown datalink: %s" device)

let get_define = fun xml name ->
  let xml = ExtXml.child ~select:(fun d -> ExtXml.tag_is d "define" && ExtXml.attrib d "name" = name) xml "define" in
  ExtXml.attrib xml "value"


(*********** Monitoring *************************************************)
type status = {
    mutable last_rx_byte : int;
    mutable last_rx_msg : int;
    mutable rx_byte : int;
    mutable rx_msg : int;
    mutable rx_err : int;
    mutable ms_since_last_msg : int
  }

let statuss = Hashtbl.create 3
let dead_aircraft_time_ms = 5000
let update_status = fun ac_id buf ->
  let status = 
    try Hashtbl.find statuss ac_id with Not_found ->
      let s = { last_rx_byte = 0; last_rx_msg = 0; rx_byte = 0; rx_msg = 0; rx_err = 0; ms_since_last_msg = dead_aircraft_time_ms } in
      Hashtbl.add statuss ac_id s;
 Printf.fprintf stdout "status airplane: %d\n" ac_id; flush stdout; 
      s in
  status.rx_byte <- status.rx_byte + String.length buf;
  status.rx_msg <- status.rx_msg + 1;
  status.rx_err <- !PprzTransport.nb_err;
  status.ms_since_last_msg <- 0

let status_msg_period = 1000 (** ms *)


let live_aircraft = fun ac_id ->
  try
    let s = Hashtbl.find statuss ac_id in
    s.ms_since_last_msg < dead_aircraft_time_ms
  with
    Not_found -> false

let send_status_msg =
  let start = Unix.gettimeofday () in
  fun () ->
    Hashtbl.iter (fun ac_id status ->
      let dt = float status_msg_period /. 1000. in
      let t = int_of_float (Unix.gettimeofday () -. start) in
      let byte_rate = float (status.rx_byte - status.last_rx_byte) /. dt
      and msg_rate = float (status.rx_msg - status.last_rx_msg) /. dt in
      status.last_rx_msg <- status.rx_msg;
      status.last_rx_byte <- status.rx_byte;
(*      Printf.fprintf stdout "%d\n" ac_id; flush stdout; *)
      status.ms_since_last_msg <- status.ms_since_last_msg + status_msg_period;
      let vs = ["run_time", Pprz.Int t;
		"rx_bytes_rate", Pprz.Float byte_rate; 
		"rx_msgs_rate", Pprz.Float msg_rate;
		"rx_err", Pprz.Int status.rx_err;
		"rx_bytes", Pprz.Int status.rx_byte;
		"rx_msgs", Pprz.Int status.rx_msg
	      ] in
      Tm_Pprz.message_send (string_of_int ac_id) "DOWNLINK_STATUS" vs)
      statuss 


let airframes =
  let conf_file = conf // "conf.xml" in
  List.fold_right (fun a r ->
    if ExtXml.tag_is a "aircraft" then
      let airframe_file = conf // ExtXml.attrib a "airframe" in
      try
	let airframe_xml = Xml.parse_file airframe_file in
	let dls = ExtXml.child ~select:(fun s -> Xml.attrib s "name" = "DATALINK") airframe_xml "section" in
	let device = get_define dls "DEVICE_TYPE"
	and addr = get_define dls "DEVICE_ADDRESS" in
	let dl = airborne_device device addr in
	(ios (ExtXml.attrib a "ac_id"), dl)::r
      with
	Not_found -> r
      |	Xml.File_not_found f ->
	  fprintf stderr "Error in '%s', file not found: %s\n" conf_file f;
	  r
      |	_ ->
	  fprintf stderr "Error in '%s', ignoring\n" airframe_file;
	  r
    else
      r)
    (Xml.children (Xml.parse_file conf_file))
    []

exception NotSendingToThis

let airborne_device = fun ac_id airframes device ->
  let ac_device = try Some (List.assoc ac_id airframes) with Not_found -> None in
  match ac_device, device with
    (None, Pprz) | (Some Uart, Pprz) -> Uart
  | (Some (WavecardDevice _ as ac_device), Wavecard) 
  | (Some (XBeeDevice as ac_device), XBee) 
  | (Some (AerocommDevice as ac_device), Aerocomm)
  | (Some (AerocommDevice_ver2 as ac_device), Aerocomm_ver2)
    -> ac_device
  | _ -> raise NotSendingToThis


let use_tele_message = fun payload ->
  let buf = Serial.string_of_payload payload in
 if (int_of_char buf.[1])=31 then begin
(*    Printf.fprintf stdout "------------->>"; flush stdout *)
 end;
  Debug.call 'l' (fun f ->  fprintf f "pprz receiving: %s\n" (Debug.xprint buf));
  try
    let (msg_id, ac_id, values) = Tm_Pprz.values_of_payload payload in
    let msg = Tm_Pprz.message_of_id msg_id in
    Tm_Pprz.message_send (string_of_int ac_id) msg.Pprz.name values;
(* Printf.fprintf stdout "msgId: %d, ac_id: %d, name: %s\n" msg_id ac_id msg.Pprz.name; flush stdout; *)
    update_status ac_id buf
  with
    _ ->
      Printf.fprintf stdout "ERROR msg: %s\n" (Debug.xprint buf); flush stdout;
      Debug.call 'W' (fun f ->  fprintf f "Warning, cannot use: %s\n" (Debug.xprint buf));


type priority = Null | Low | Normal | High

(******** Wavecard ******************************************************)
module Wc = struct
  type status = Ready | Busy
    
  let buffer_size = 5
  let null_buffer_entry = (Null, Unix.stdout, (W.ACK, ""))
  let priority_of = fun (p, _, _) -> p
  let buffer = (ref Ready, Array.create buffer_size null_buffer_entry)
  let timer = ref None
  let remove_timer = fun () ->
    match !timer with
      None -> ()
    | Some t -> GMain.Timeout.remove t

  let shift_buffer = fun b ->
    for i = 0 to buffer_size - 2 do (** A circular buf would be better *)
      b.(i) <- b.(i+1)
    done;
    b.(buffer_size-1) <- null_buffer_entry

  let rec repeat_send = fun fd cmd n ->
    W.send fd cmd;
    timer := Some (GMain.Timeout.add 300 (fun _ -> Debug.trace 'b' (sprintf "Retry %d" n); repeat_send fd cmd (n+1); false))

  let rec flush = fun () ->
    let status, b = buffer in
    if !status = Ready then
      let (priority, fd, cmd) = b.(0) in
      if priority <> Null then begin
	shift_buffer b;
	status := Busy;
	repeat_send fd cmd 0
      end

  let buffer_ready = fun () ->
    remove_timer ();
    let (status, b) = buffer in
    shift_buffer b;
    status := Ready;
    flush ()
	
	  	  
  let send_buffered = fun fd cmd priority ->
    let _status, b = buffer in
    (** Set the message in the right place in the buffer *)
    let rec loop = fun i ->
      if i < buffer_size then
	if priority_of b.(i) >= priority
	then loop (i+1)
	  else begin
	    for j = i + 1 to buffer_size - 1 do (** Shift *)
	      b.(j) <- b.(j-1)
	    done;
	    Debug.trace 'b' (sprintf "Set in %d" i);
	    b.(i) <- (priority, fd, cmd)
	  end 
      else
	Debug.trace 'b' "Buffer full" in
    loop 0;
    flush ()

  let send = fun fd addr payload priority ->
    let data = W.addressed addr (Serial.string_of_payload payload) in
    send_buffered fd (W.REQ_SEND_MESSAGE, data) priority

  let ack_delay = 10 (* ms *)
  let send_ack = fun fd () ->
    Debug.trace 'w' (sprintf "%.2f send ACK" (Unix.gettimeofday ()));
    ignore (GMain.Timeout.add ack_delay (fun _ -> W.send fd (W.ACK, ""); false))
  let use_message = fun (com, data) ->
    match com with
      W.RECEIVED_FRAME ->
	use_tele_message (Serial.payload_of_string data)
    | W.RES_SEND_FRAME ->
	Debug.trace 'b' "RES_SEND_FRAME";
	ignore (GMain.Timeout.add 100 (fun _ -> buffer_ready (); false))
	
    | W.RES_READ_REMOTE_RSSI ->
	Tm_Pprz.message_send "link" "WC_RSSI" ["raw_level", Pprz.Int (Char.code data.[0])];
	Debug.call 'w' (fun f -> fprintf f "%.2f wv remote RSSI %d\n" (Unix.gettimeofday ()) (Char.code data.[0]));
	ignore (GMain.Timeout.add 100 (fun _ -> buffer_ready (); false))
    | W.RES_READ_RADIO_PARAM ->
	Ivy.send (sprintf "WC_ADDR %s" data);
	Debug.call 'w' (fun f -> fprintf f "wv local addr : %s\n" (Debug.xprint data));
    | W.ACK -> 
	Debug.trace 'w' (sprintf "%.2f wv ACK" (Unix.gettimeofday ()))
    | _ -> 
	Debug.call 'w' (fun f -> fprintf f "wv receiving: %02x %s\n" (W.code_of_cmd com) (Debug.xprint data));
	()

  let rssi_period = 5000 (** ms *)
  let req_rssi = fun device addr ->
    let data = W.addressed addr "" in
    send_buffered device.fd (W.REQ_READ_REMOTE_RSSI, data) Low

  let init = fun device rssi_id ->
    (** Set the wavecard in short wakeup mode *)
    let data = String.create 2 in
    data.[0] <- Char.chr (W.code_of_config_param W.WAKEUP_TYPE);
    data.[1] <- Char.chr (W.code_of_wakeup_type W.SHORT_WAKEUP);
(***          data.[0] <- Char.chr (W.code_of_config_param W.AWAKENING_PERIOD);
   data.[1] <- Char.chr 10; ***)
    W.send device.fd (W.REQ_WRITE_RADIO_PARAM,data);
    
    (* request own address *)
    let s = String.make 1 (char_of_int 5) in
    ignore (GMain.Timeout.add 1500 (fun _ -> W.send device.fd (W.REQ_READ_RADIO_PARAM, s); false));
    
    (** Ask for rssi if required *)
    if rssi_id >= 0 then begin
      match airborne_device rssi_id airframes device.transport with
	WavecardDevice addr ->
	  ignore (GMain.Timeout.add rssi_period (fun _ -> req_rssi device addr; true))
      | _ -> failwith (sprintf "Rssi not supported by A/C '%d'" rssi_id)
    end
	
end (** Wc module *)



module XB = struct (** XBee module *)
  let nb_retries = ref 10
  let retry_delay = 200 (* ms *) 

  let at_init_period = 2000 (* ms *)

  let my_addr = ref 0x100

  let switch_to_api = fun device ->
    let o = Unix.out_channel_of_descr device.fd in
    Debug.trace 'x' "config xbee";
    fprintf o "%s%!" (Xbee.at_set_my !my_addr);
    fprintf o "%s%!" (Xbee.at_set_baud_rate device.baud_rate);
    fprintf o "%s%!" Xbee.at_api_enable;
    fprintf o "%s%!" Xbee.at_exit;
    Debug.trace 'x' "end init xbee"

  let init = fun device ->
    Debug.trace 'x' "init xbee";
    let o = Unix.out_channel_of_descr device.fd in
    fprintf o "%s%!" Xbee.at_command_sequence;
    ignore (Glib.Timeout.add at_init_period (fun () -> switch_to_api device; false))

  (* Array of sent packets for retry: (packet, nb of retries) *)
  let packets = Array.create 256 ("", -1)

  (* Frame id generation > 0 and < 256 *)
  let gen_frame_id = 
    let x = ref 0 in
    fun () -> 
      incr x;
      if !x >= 256 then
	x := 1;
      !x

  let use_message = fun device frame_data ->
    let frame_data = Serial.string_of_payload frame_data in
    Debug.trace 'x' (Debug.xprint frame_data);
    match Xbee.api_parse_frame frame_data with
      Xbee.Modem_Status x ->
	Debug.trace 'x' (sprintf "getting XBee status %d" x)
    | Xbee.AT_Command_Response (frame_id, comm, status, value) ->
	Debug.trace 'x' (sprintf "getting XBee AT command response: %d %s %d %s" frame_id comm status (Debug.xprint value))
    | Xbee.TX_Status (frame_id, status) ->
	Debug.trace 'x' (sprintf "getting XBee TX status: %d %d" frame_id status);
	if status = 1 then (* no ack, retry *)
	  let (packet, nb_prev_retries) = packets.(frame_id) in
	  if nb_prev_retries < !nb_retries then begin
	    packets.(frame_id) <- (packet, nb_prev_retries+1);
	    let o = Unix.out_channel_of_descr device.fd in
	    ignore (GMain.Timeout.add (10 + Random.int retry_delay)
	      (fun _ -> 
		fprintf o "%s%!" packet;
		Debug.call 'y' (fun f -> fprintf f "Resending (%d) %s\n" (nb_prev_retries+1) (Debug.xprint packet));
		false));
	  end else
	    fprintf stderr "FIXME: nb_retries exceeded\n"
	  
    | Xbee.RX_Packet_64 (addr64, rssi, options, data) ->
	Debug.trace 'x' (sprintf "getting XBee RX64: %Lx %d %d %s" addr64 rssi options (Debug.xprint data));
	use_tele_message (Serial.payload_of_string data)
    | Xbee.RX_Packet_16 (addr16, rssi, options, data) ->
	Debug.trace 'x' (sprintf "getting XBee RX16: from=%x %d %d %s" addr16 rssi options (Debug.xprint data));
	use_tele_message (Serial.payload_of_string data)


  let send = fun ac_id device rf_data ->
    let rf_data = Serial.string_of_payload rf_data in
    let frame_id = gen_frame_id () in
    let frame_data = Xbee.api_tx16 ~frame_id ac_id rf_data in
    let packet = Xbee.Protocol.packet (Serial.payload_of_string frame_data) in

    (* Store the packet for further retry *)
    packets.(frame_id) <- (packet, 1);

    let o = Unix.out_channel_of_descr device.fd in
    fprintf o "%s%!" packet;
    Debug.call 'y' (fun f -> fprintf f "link sending (%d): (%s) %s\n" frame_id (Debug.xprint rf_data) (Debug.xprint packet));
end (** XBee module *)


module ACMM = struct (** Aerocomm module *)
  let nb_retries = ref 10
  let retry_delay = 200 (* ms *) 

  let at_init_period = 2000 (* ms *)

  let my_addr = ref 0x100

  let switch_to_api = fun device ->
    let o = Unix.out_channel_of_descr device.fd in
    Debug.trace 'x' "config xbee";
    fprintf o "%s%!" (Aerocomm.at_set_my !my_addr);
    fprintf o "%s%!" (Aerocomm.at_set_baud_rate device.baud_rate);
    fprintf o "%s%!" Aerocomm.at_api_enable;
    fprintf o "%s%!" Aerocomm.at_exit; 
    Debug.trace 'x' "end init xbee"

  let init = fun device ->
    Debug.trace 'x' "init xbee";
    let o = Unix.out_channel_of_descr device.fd in
    fprintf o "%s%!" Aerocomm.at_command_sequence;
(*    ignore (Glib.Timeout.add at_init_period (fun () -> switch_to_api device; false))  *)
    fprintf o "%s%!" Aerocomm.at_exit

  (* Array of sent packets for retry: (packet, nb of retries) *)
  let packets = Array.create 256 ("", -1)

  (* Frame id generation > 0 and < 256 *)
  let gen_frame_id = 
    let x = ref 0 in
    fun () -> 
      incr x;
      if !x >= 256 then
	x := 1;
      !x

  let use_message = fun device frame_data ->
    let frame_data = Serial.string_of_payload frame_data in
    Debug.trace 'x' (Debug.xprint frame_data); 
    match Aerocomm.api_parse_frame frame_data with
      Aerocomm.API_Send_Data_Complete(rssi, status) ->
	Debug.trace 'x' (sprintf "getting Aerocomm TX status: %d %d" rssi status);
    | Aerocomm.API_Receive(addr16, data) ->
	Debug.trace 'x' (sprintf "getting Aerocomm RX: %x %s" addr16 (Debug.xprint data));
	use_tele_message (Serial.payload_of_string data)
    | Aerocomm.API_Enchanced_Receive (addr16, rssi, data) ->
	Debug.trace 'x' (sprintf "getting Aerocomm enchanced RX: from=%x %d %s" addr16 rssi (Debug.xprint data));
(* Printf.fprintf stdout "getting Aerocomm enchanced RX: from=%x %d %s\n" addr16 rssi (Debug.xprint data); flush stdout; *) 
	use_tele_message (Serial.payload_of_string data)
    | Aerocomm.API_Transmit_Packet (addr16, retries, data) ->
	Debug.trace 'x' (sprintf "getting Aerocomm enchanced RX: from=%x %d %s" addr16 retries (Debug.xprint data));
	use_tele_message (Serial.payload_of_string data)


  let send = fun ac_id device rf_data ->
    let rf_data = Serial.string_of_payload rf_data in
    let frame_id = gen_frame_id () in
    let frame_data = Aerocomm.api_tx ac_id nb_retries.contents rf_data in
(*    let packet = Serial.payload_of_string frame_data in *)

    (* Store the packet for further retry *)
    packets.(frame_id) <- (frame_data, 1);

    let o = Unix.out_channel_of_descr device.fd in
    fprintf o "%s%!" frame_data;
Printf.fprintf stdout "----------------->Sending to %d <-------" ac_id; flush stdout;
    for j=0 to String.length frame_data -1 do Printf.fprintf stdout "%x " (int_of_char frame_data.[j]) done;
    Printf.fprintf stdout "\n";flush stdout;

    Debug.call 'y' (fun f -> fprintf f "link sending (%d): (%s) %s\n" frame_id (Debug.xprint rf_data) (Debug.xprint frame_data));
end (** Aerocomm module *)

module ACMM_ver2 = struct (** Aerocomm module *)
  let nb_retries = ref 10
  let retry_delay = 200 (* ms *) 

  let at_init_period = 2000 (* ms *)

  let my_addr = ref 0x100

  let switch_to_api = fun device ->
    let o = Unix.out_channel_of_descr device.fd in
    Debug.trace 'x' "config xbee";
    fprintf o "%s%!" (Aerocomm.at_set_my !my_addr);
    fprintf o "%s%!" (Aerocomm.at_set_baud_rate device.baud_rate);
    fprintf o "%s%!" Aerocomm.at_api_enable;
    fprintf o "%s%!" Aerocomm.at_exit; 
    Debug.trace 'x' "end init xbee"

  let init = fun device ->
    Debug.trace 'x' "init xbee";
    let o = Unix.out_channel_of_descr device.fd in
    fprintf o "%s%!" Aerocomm.at_command_sequence;
(*    ignore (Glib.Timeout.add at_init_period (fun () -> switch_to_api device; false))  *)
    fprintf o "%s%!" Aerocomm.at_exit

  (* Array of sent packets for retry: (packet, nb of retries) *)
  let packets = Array.create 256 ("", -1)

  (* Frame id generation > 0 and < 256 *)
  let gen_frame_id = 
    let x = ref 0 in
    fun () -> 
      incr x;
      if !x >= 256 then
	x := 1;
      !x

  let n= ref 0
  let i= ref 0
  let j= ref 0
  let formatError = ref false

  let use_message = fun device frame_data ->
    let frame_data = Serial.string_of_payload frame_data in
    Debug.trace 'x' (Debug.xprint frame_data); 
    match Aerocomm.api_parse_frame frame_data with
      Aerocomm.API_Send_Data_Complete(rssi, status) ->
	Debug.trace 'x' (sprintf "getting Aerocomm TX status: %d %d" rssi status);
    | Aerocomm.API_Receive(addr16, data) ->
	Debug.trace 'x' (sprintf "getting Aerocomm RX: %x %s" addr16 (Debug.xprint data));
	use_tele_message (Serial.payload_of_string data)
    | Aerocomm.API_Enchanced_Receive (addr16, rssi, data) ->
	Debug.trace 'x' (sprintf "getting Aerocomm enchanced RX: from=%x %d %s" addr16 rssi (Debug.xprint data));
(*   Printf.fprintf stdout "getting Aerocomm enchanced RX: from=%x RSSI=%x %s\n" addr16 rssi (Debug.xprint data); flush stdout; *)     
        n:=String.length data;
        i:=0;
        if !i < !n then j:= (int_of_char data.[!i]);
(* Printf.fprintf stdout "START PARSING\n"; flush stdout; *) 
	if  !i + 1 + !j >= !n then formatError:=true
       	else if !j<2 then formatError:=true
       	else if int_of_char data.[!i + !j + 1] <> 0xFF then formatError:=true
	else formatError:=false;
	while !formatError && !i < !n do
(*  Printf.fprintf stdout "looking for divider..."; flush stdout; *)  
       		while !i < !n && int_of_char data.[!i] <> 0xFF do i:=!i+1 done;
		i:=!i+1;
		if !i < !n then j:=int_of_char data.[!i];
(*  Printf.fprintf stdout "found at i=%d\n" !i; flush stdout; *)  
		if  !i + !j + 1 >= !n then formatError:=true
       		else if !j<2 then formatError:=true
       		else if int_of_char data.[!i + !j + 1] <> 0xFF then formatError:=true
		else formatError:=false;
	done;
  
(*  Printf.fprintf stdout "n=%d i=%d len=%d\n" !n !i !j; flush stdout; *) 
	while !i + 1 + !j < !n do
(*  Printf.fprintf stdout "*1)  n=%d i=%d len=%d\n" !n !i !j; flush stdout; *)
		use_tele_message (Serial.payload_of_string (String.sub data (!i+1) !j));			
		i:=!i + !j + 2;
(*  Printf.fprintf stdout "message sent\n"; flush stdout; *)
(*  Printf.fprintf stdout "*2)  n=%d i=%d len=%d\n" !n !i !j; flush stdout; *)
		if !i < !n then j:=int_of_char data.[!i];
(*  Printf.fprintf stdout "1)  n=%d i=%d len=%d\n" !n !i !j; flush stdout; *) 
		if  !i + !j + 1 >= !n then formatError:=true
        	else if !j<2 then formatError:=true
        	else if int_of_char data.[!i + !j + 1] <> 0xFF then formatError:=true
		else formatError:=false;

		while !formatError && !i < !n do
(*  Printf.fprintf stdout "looking for divider..."; flush stdout; *)  
       			while !i < !n && int_of_char data.[!i] <> 0xFF do i:=!i+1 done;
			i:=!i+1;
			if !i < !n then j:=int_of_char data.[!i];
(*  Printf.fprintf stdout "found at i=%d\n" !i; flush stdout; *)  
			if  !i + !j + 1 >= !n then formatError:=true
       			else if !j<2 then formatError:=true
       			else if int_of_char data.[!i + !j + 1] <> 0xFF then formatError:=true
			else formatError:=false;
		done;

(*  Printf.fprintf stdout "2)   n=%d i=%d len=%d\n" !n !i !j; flush stdout; *)  

        done
     | Aerocomm.API_Transmit_Packet (addr16, retries, data) ->
	Debug.trace 'x' (sprintf "getting Aerocomm enchanced RX: from=%x %d %s" addr16 retries (Debug.xprint data));
	use_tele_message (Serial.payload_of_string data)


  let send = fun ac_id device rf_data ->
    let rf_data = Serial.string_of_payload rf_data in
    let frame_id = gen_frame_id () in
    let frame_data = Aerocomm.api_tx ac_id nb_retries.contents rf_data in
(*    let packet = Serial.payload_of_string frame_data in *)

    (* Store the packet for further retry *)
    packets.(frame_id) <- (frame_data, 1);

    let o = Unix.out_channel_of_descr device.fd in
    fprintf o "%s%!" frame_data;
Printf.fprintf stdout "----------------->Sending to %d <-------" ac_id; flush stdout;
    for j=0 to String.length frame_data -1 do Printf.fprintf stdout "%x " (int_of_char frame_data.[j]) done;
    Printf.fprintf stdout "\n";flush stdout;

    Debug.call 'y' (fun f -> fprintf f "link sending (%d): (%s) %s\n" frame_id (Debug.xprint rf_data) (Debug.xprint frame_data));
end (** Aerocomm new module *)

let send = fun ac_id device ac_device payload priority ->
  match ac_device with
    Uart ->
      let o = Unix.out_channel_of_descr device.fd in
      let buf = Pprz.Transport.packet payload in
      Printf.fprintf o "%s" buf; flush o;
      Debug.call 'l' (fun f -> fprintf f "mm sending: %s\n" (Debug.xprint buf));
  | WavecardDevice addr ->
      Wc.send device.fd addr payload priority
  | XBeeDevice ->
      XB.send ac_id device payload
  | AerocommDevice ->
      ACMM.send ac_id device payload
  | AerocommDevice_ver2 ->
      ACMM_ver2.send ac_id device payload



let cm_of_m = fun f -> Pprz.Int (truncate (100. *. f))

(** Got a FLIGHT_PARAM message and dispatch a ACINFO *)
let get_fp = fun device _sender vs ->
  let ac_id = int_of_string (Pprz.string_assoc "ac_id" vs) in
  List.iter 
    (fun (dest_id, _) ->
      if dest_id <> ac_id && live_aircraft dest_id then (** Do not send to itself *)
	try
	  Debug.trace 'b' (sprintf "ACINFO %d for %d" ac_id dest_id);
	  let ac_device = airborne_device dest_id airframes device.transport in
	  let f = fun a -> Pprz.float_assoc a vs in
	  let lat = (Deg>>Rad) (f "lat")
	  and long = (Deg>>Rad) (f "long")
	  and course = f "course"
	  and alt = f "alt"
	  and gspeed = f "speed" in
	  let utm = Latlong.utm_of WGS84 {posn_lat=lat; posn_long=long} in
	  let vs = ["ac_id", Pprz.Int ac_id;
		    "utm_east", cm_of_m utm.utm_x;
		    "utm_north", cm_of_m utm.utm_y;
		    "course", Pprz.Int (truncate (10. *. course));
		    "alt", cm_of_m alt;
		    "speed", cm_of_m gspeed] in
	  let msg_id, _ = Dl_Pprz.message_of_name "ACINFO" in
	  let s = Dl_Pprz.payload_of_values msg_id my_id vs in
	  send dest_id device ac_device s Low
	with
	  _NotSendingToThis -> ())
    airframes

(** Got a MOVE_WAYPOINT and send a MOVE_WP *)
let move_wp = fun device _sender vs ->
  Debug.call 'm' (fun f -> fprintf f "mm MOVE WAYPOINT\n");
  let ac_id = int_of_string (Pprz.string_assoc "ac_id" vs) in
  try
    let ac_device = airborne_device ac_id airframes device.transport in
    let f = fun a -> Pprz.float_assoc a vs in
    let lat = f "lat"
    and long = f "long"
    and alt = f "alt"
    and wp_id = Pprz.int_assoc "wp_id" vs in
    let wgs84 = {posn_lat=(Deg>>Rad)lat;posn_long=(Deg>>Rad)long} in
    let utm = Latlong.utm_of WGS84 wgs84 in
    let vs = ["wp_id", Pprz.Int wp_id;
	      "utm_east", cm_of_m utm.utm_x;
	      "utm_north", cm_of_m utm.utm_y;
	      "alt", cm_of_m alt] in
    let msg_id, _ = Dl_Pprz.message_of_name "MOVE_WP" in
    let s = Dl_Pprz.payload_of_values msg_id my_id vs in
    send ac_id device ac_device s High
  with
    NotSendingToThis -> ()

(** Got a DL_SETTING, and send an SETTING *)
let setting = fun device _sender vs ->
  let ac_id = int_of_string (Pprz.string_assoc "ac_id" vs) in
  try
    let ac_device = airborne_device ac_id airframes device.transport in
    let idx = Pprz.int_assoc "index" vs in
    let vs = ["index", Pprz.Int idx; "value", List.assoc "value" vs] in
    let msg_id, _ = Dl_Pprz.message_of_name "SETTING" in
    let s = Dl_Pprz.payload_of_values msg_id my_id vs in
    send ac_id device ac_device s High
  with
    NotSendingToThis -> ()

(** Got a JUMP_TO_BLOCK, and send an BLOCK *)
let jump_block = fun device _sender vs ->
  Debug.call 'j' (fun f -> fprintf f "mm JUMP_TO_BLOCK\n");
  let ac_id = int_of_string (Pprz.string_assoc "ac_id" vs) in
  try
    let ac_device = airborne_device ac_id airframes device.transport in
    let block_id = Pprz.int_assoc "block_id" vs in
    let vs = ["block_id", Pprz.Int block_id] in
    let msg_id, _ = Dl_Pprz.message_of_name "BLOCK" in
    let s = Dl_Pprz.payload_of_values msg_id my_id vs in
    send ac_id device ac_device s High
  with
    NotSendingToThis -> ()

(** Got a RAW_DATALINK message *)
let raw_datalink = fun device _sender vs ->
  let ac_id = int_of_string (Pprz.string_assoc "ac_id" vs) in
  try
    let ac_device = airborne_device ac_id airframes device.transport in
    let m = Pprz.string_assoc "message" vs in
    for i = 0 to String.length m - 1 do
      if m.[i] = ';' then m.[i] <- ' '
    done;
    let msg_id, vs = Dl_Pprz.values_of_string m in
    let s = Dl_Pprz.payload_of_values msg_id my_id vs in
    send ac_id device ac_device s Normal
  with
    NotSendingToThis -> ()


module PprzModem = struct

  let msg_period = 1000 (** ms *)

(** Modem monitoring messages *)
  let send_msg = fun () ->
    let vs = ["valim", Pprz.Float Modem.status.Modem.valim;
	      "detected", Pprz.Int Modem.status.Modem.detected;
	      "cd", Pprz.Int Modem.status.Modem.cd;
	      "nb_err", Pprz.Int Modem.status.Modem.nb_err;
	      "nb_byte", Pprz.Int Modem.status.Modem.nb_byte;
	      "nb_msg", Pprz.Int Modem.status.Modem.nb_msg
	    ] in
    Tm_Pprz.message_send "modem" "MODEM_STATUS" vs
      
  let use_message =
    let buffer = ref "" in
    fun payload ->
      let msg = Serial.string_of_payload payload in
      Debug.call 'M' (fun f -> fprintf f "use_modem: %s\n" (Debug.xprint msg));
      match Modem.parse_payload payload with
	None -> () (* Only internal modem data *)
      | Some data ->
	  (** Accumulate in a buffer *)
	  let b = !buffer ^ data in
	  Debug.call 'M' (fun f -> fprintf f "Pprz buffer: %s\n" (Debug.xprint b));
	  (** Parse as pprz message and ... *)
	  let x = PprzTransport.parse use_tele_message b in
	  (** ... remove from the buffer the chars which have been used *)
	  buffer := String.sub b x (String.length b - x)
end (* PprzModem module *)


(*************** Audio *******************************************************)
module Audio = struct
  let use_data =
    let buffer = ref "" in
    fun data -> 
      let b = !buffer ^ data in
      let n = PprzTransport.parse use_tele_message b in
      buffer := String.sub b n (String.length b - n)
end







let parse_of_transport device = function
    Pprz -> 
      PprzTransport.parse use_tele_message
  | Modem -> 
      let module ModemTransport = Serial.Transport(Modem.Protocol) in
      ModemTransport.parse PprzModem.use_message
  | Wavecard ->
      fun buf -> Wavecard.parse buf ~ack:(Wc.send_ack device.fd) (Wc.use_message)
  | XBee ->
      let module XbeeTransport = Serial.Transport (Xbee.Protocol) in
      XbeeTransport.parse (XB.use_message device)
  | Aerocomm ->
      let module AerocommTransport = Serial.Transport (Aerocomm.Protocol) in
      AerocommTransport.parse (ACMM.use_message device)
  | Aerocomm_ver2 ->
      let module AerocommTransport = Serial.Transport (Aerocomm.Protocol) in
      AerocommTransport.parse (ACMM_ver2.use_message device)
    

let _ =
  let ivy_bus = ref "127.255.255.255:2010" in
  let port = ref "/dev/ttyS0" in
  let baurate = ref "9600" in
  let transport = ref "pprz" in
  let uplink = ref false in
  let audio = ref false in
  let rssi_id = ref (-1) in
  let dtr = ref false in
  
  let options =
    [ "-b", Arg.Set_string ivy_bus, (sprintf "<ivy bus> Default is %s" !ivy_bus);
      "-d", Arg.Set_string port, (sprintf "<port> Default is %s" !port);
      "-rssi", Arg.Set_int rssi_id, (sprintf "<ac_id> Periodically requests rssi level from the distant wavecard");
      "-xbee_addr", Arg.Set_int XB.my_addr, (sprintf "<my_addr> (%d)" !XB.my_addr);
      "-xbee_retries", Arg.Set_int XB.my_addr, (sprintf "<nb retries> (%d)" !XB.nb_retries);
      "-aerocomm_addr", Arg.Set_int ACMM.my_addr, (sprintf "<my_addr> (%d)" !ACMM.my_addr);
      "-aerocomm_retries", Arg.Set_int ACMM.my_addr, (sprintf "<nb retries> (%d)" !ACMM.nb_retries);
      "-transport", Arg.Set_string transport, (sprintf "<transport> Available protocols are modem,pprz,wavecard, xbee, and aerocomm. Default is %s" !transport);
      "-uplink", Arg.Set uplink, (sprintf "Uses the link as uplink also.");
      "-dtr", Arg.Set dtr, "Set serial DTR to false (aerocomm)";
      "-audio", Arg.Unit (fun () -> audio := true; port := "/dev/dsp"), (sprintf "Listen a modulated audio signal on <port>. Sets <port> to /dev/dsp (the -d option must used after this one if needed)");
      "-s", Arg.Set_string baurate, (sprintf "<baudrate>  Default is %s" !baurate)] in
  Arg.parse
    options
    (fun _x -> ())
    "Usage: ";

  Ivy.init "Link" "READY" (fun _ _ -> ());
  Ivy.start !ivy_bus;


  try    
    let transport = 
      match !transport with
	"modem" -> Modem
      | "pprz" -> Pprz
      | "wavecard" -> Wavecard
      | "xbee" -> XBee
      | "aerocomm" -> Aerocomm
      | "aerocomm__" -> Aerocomm_ver2
      | x -> invalid_arg (sprintf "transport_of_string: %s" x)
    in

    (** Listen on a serial device or on multimon pipe or on audio *)
    let on_serial_device = 
      String.length !port >= 4 && String.sub !port 0 4 = "/dev" in (* FIXME *)
    let fd = 
      if !audio then
	Demod.init !port
      else
	if on_serial_device then
	  Serial.opendev !port (Serial.speed_of_baudrate !baurate)
	else 
	  Unix.openfile !port [Unix.O_RDWR] 0o640
    in

    if !dtr then
      Serial.set_dtr fd false;

    
    let device = { fd=fd; transport=transport; baud_rate=int_of_string !baurate } in

    (* Listening *)
    let buffered_input =
      let parse = parse_of_transport device transport in
      match Serial.input parse with
	Serial.Closure f -> f in
    let cb = 
      if !audio then
	fun _ ->
	  let (data_left, _data_right) = Demod.get_data () in
	  Audio.use_data data_left;
	  true
      else
	fun _ -> buffered_input fd; true
    in
    ignore (Glib.Io.add_watch [`HUP] (fun _ -> exit 1)  (GMain.Io.channel_of_descr fd));
    ignore (Glib.Io.add_watch [`IN] cb (GMain.Io.channel_of_descr fd));


    if !uplink then begin
      (** Listening on Ivy (FIXME: remove the ad hoc messages) *)
(***)       ignore (Ground_Pprz.message_bind "FLIGHT_PARAM" (get_fp device)); (***)
      ignore (Ground_Pprz.message_bind "MOVE_WAYPOINT" (move_wp device));
      ignore (Ground_Pprz.message_bind "DL_SETTING" (setting device));
      ignore (Ground_Pprz.message_bind "JUMP_TO_BLOCK" (jump_block device));
      ignore (Ground_Pprz.message_bind "RAW_DATALINK" (raw_datalink device))
    end;


    (** Init and Periodic tasks *)
    begin
      ignore (Glib.Timeout.add status_msg_period (fun () -> send_status_msg (); true));

      match transport with
	Modem ->
	  (** Sending periodically modem and downlink status messages *)
	  ignore (Glib.Timeout.add PprzModem.msg_period (fun () -> PprzModem.send_msg (); true))
      | Wavecard ->
	  Wc.init device !rssi_id
      | XBee ->
	  XB.init device
      | Aerocomm ->
	  ACMM.init device
      | _ -> ()
    end;


    (* Main Loop *)
    let loop = Glib.Main.create true in
    while Glib.Main.is_running loop do
      ignore (Glib.Main.iteration true)
    done
  with
    Xml.Error e -> prerr_endline (Xml.error e); exit 1
  | exn -> fprintf stderr "%s\n" (Printexc.to_string exn)
