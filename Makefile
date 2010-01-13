#   Paparazzi main $Id: Makefile 3726 2009-07-18 18:22:45Z poine $
#   Copyright (C) 2004 Pascal Brisset Antoine Drouin
#
# This file is part of paparazzi.
#
# paparazzi is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.
#
# paparazzi is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with paparazzi; see the file COPYING.  If not, write to
# the Free Software Foundation, 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.  

# The default is to produce a quiet echo of compilation commands
# Launch with "make Q=''" to get full echo
Q=@

ifeq ($(Q),@)
MAKEFLAGS += --no-print-directory
endif

PAPARAZZI_SRC=$(shell pwd)
empty=
space=$(empty) $(empty)
ifneq ($(findstring $(space),$(PAPARAZZI_SRC)),)
  $(error No fucking spaces allowed in the current directory name)
endif
ifeq ($(PAPARAZZI_HOME),)
PAPARAZZI_HOME=$(PAPARAZZI_SRC)
endif

LIB=sw/lib
AIRBORNE=sw/airborne
COCKPIT=sw/ground_segment/cockpit
TMTC=sw/ground_segment/tmtc
MULTIMON=sw/ground_segment/multimon
LOGALIZER=sw/logalizer
SIMULATOR=sw/simulator
MAKE=make PAPARAZZI_SRC=$(PAPARAZZI_SRC) PAPARAZZI_HOME=$(PAPARAZZI_HOME)
CONF=$(PAPARAZZI_SRC)/conf
STATICINCLUDE =$(PAPARAZZI_HOME)/var/include
MESSAGES_H=$(STATICINCLUDE)/messages.h
MESSAGES_FBW_H=$(STATICINCLUDE)/messages_fbw.h
UBX_PROTOCOL_H=$(STATICINCLUDE)/ubx_protocol.h
XSENS_PROTOCOL_H=$(STATICINCLUDE)/xsens_protocol.h
DL_PROTOCOL_H=$(STATICINCLUDE)/dl_protocol.h
MESSAGES_XML = $(CONF)/messages.xml
UBX_XML = $(CONF)/ubx.xml
XSENS_XML = $(CONF)/xsens_MTi-G.xml
TOOLS=$(PAPARAZZI_SRC)/sw/tools
ARMGCC=/usr/bin/arm-elf-gcc


all: static conf

static : static_h
#static : lib center tools cockpit multimon tmtc logalizer lpc21iap sim_static static_h usb_lib

conf: conf/conf.xml conf/control_panel.xml

conf/%.xml :conf/%.xml.example 
	[ -L $@ ] || [ -f $@ ] || cp $< $@ 


lib:
	cd $(LIB)/ocaml; $(MAKE)

center: lib
	cd sw/supervision; make

tools: lib
	cd $(TOOLS); make

logalizer: lib
	cd $(LOGALIZER); $(MAKE)

sim_static :
	cd $(SIMULATOR); $(MAKE) PAPARAZZI_SRC=$(PAPARAZZI_SRC)

cockpit: lib
	cd $(COCKPIT); $(MAKE) all

tmtc: lib
	cd $(TMTC); $(MAKE) all

multimon:
	cd $(MULTIMON); $(MAKE)

static_h: $(MESSAGES_H) $(UBX_PROTOCOL_H) $(XSENS_PROTOCOL_H) $(DL_PROTOCOL_H)

usb_lib:
	@[ -d sw/airborne/arm7/lpcusb ] && ((test -x $(ARMGCC) && (cd sw/airborne/arm7/lpcusb; $(MAKE))) || echo "Not building usb_lib: ARMGCC=$(ARMGCC) not found") || echo "Not building usb_lib: sw/airborne/arm7/lpcusb directory missing"

$(MESSAGES_H) : $(MESSAGES_XML) $(CONF_XML) $(TOOLS)/gen_messages.out
	$(Q)test -d $(STATICINCLUDE) || mkdir -p $(STATICINCLUDE)
	@echo BUILD $@
	$(Q)PAPARAZZI_SRC=$(PAPARAZZI_SRC) $(TOOLS)/gen_messages.out $< telemetry > /tmp/msg.h
	$(Q)mv /tmp/msg.h $@
	$(Q)chmod a+r $@

$(UBX_PROTOCOL_H) : $(UBX_XML) $(TOOLS)/gen_ubx.out
	@echo BUILD $@
	$(Q)PAPARAZZI_SRC=$(PAPARAZZI_SRC) $(TOOLS)/gen_ubx.out $< > /tmp/ubx.h
	$(Q)mv /tmp/ubx.h $@

$(XSENS_PROTOCOL_H) : $(XSENS_XML) $(TOOLS)/gen_xsens.out
	@echo BUILD $@
	$(Q)PAPARAZZI_SRC=$(PAPARAZZI_SRC) $(TOOLS)/gen_xsens.out $< > /tmp/xsens.h
	$(Q)mv /tmp/xsens.h $@

$(DL_PROTOCOL_H) : $(MESSAGES_XML) $(TOOLS)/gen_messages.out
	@echo BUILD $@
	$(Q)PAPARAZZI_SRC=$(PAPARAZZI_SRC) $(TOOLS)/gen_messages.out $< datalink > /tmp/dl.h
	$(Q)mv /tmp/dl.h $@

include Makefile.ac

sim : sim_static


ac_h ac1 ac2 ac3 ac fbw ap: static conf

##### preliminary hard wired arm7 bootloader rules
#
#
# call with : make bl PROC=[TINY|FBW|AP|GENERIC]
bl:
	cd $(AIRBORNE)/arm7/test/bootloader; make clean; make 

BOOTLOADER_DEV=/dev/ttyUSB0
upload_bl bl.upload: bl
	lpc21isp -control $(AIRBORNE)/arm7/test/bootloader/bl.hex $(BOOTLOADER_DEV) 38400 12000

lpc21iap:
	cd sw/ground_segment/lpc21iap; make

upgrade_bl bl.upgrade: bl lpc21iap
	$(PAPARAZZI_SRC)/sw/ground_segment/lpc21iap/lpc21iap $(AIRBORNE)/arm7/test/bootloader/bl_ram.elf
	$(PAPARAZZI_SRC)/sw/ground_segment/lpc21iap/lpc21iap $(AIRBORNE)/arm7/test/bootloader/bl.elf

ms:
	cd $(AIRBORNE)/arm7/lpcusb; make
	cd $(AIRBORNE)/arm7/lpcusb/examples; make 

upload_ms ms.upload: ms
	$(PAPARAZZI_SRC)/sw/ground_segment/lpc21iap/lpc21iap $(AIRBORNE)/arm7/lpcusb/examples/msc.elf

#####
#####

doxygen:
	mkdir -p dox
	doxygen Doxyfile

run_sitl :
	$(PAPARAZZI_HOME)/var/$(AIRCRAFT)/sim/simsitl

install :
	make -f Makefile.install PREFIX=$(PREFIX)

uninstall :
	make -f Makefile.install PREFIX=$(PREFIX) uninstall

DISTRO=lenny
deb :
	chmod u+x debian/rules
	cp debian/control.$(DISTRO) debian/control
	cp debian/changelog.$(DISTRO) debian/changelog
	dpkg-buildpackage $(DEBFLAGS) -Ivar -rfakeroot

fast_deb:
	make deb OCAMLC=ocamlc.opt DEBFLAGS=-b

clean:
	rm -fr dox build-stamp configure-stamp conf/%gconf.xml debian/files debian/paparazzi-arm7 debian/paparazzi-avr debian/paparazzi-base debian/paparazzi-bin debian/paparazzi-dev
	rm -f  $(MESSAGES_H) $(UBX_PROTOCOL_H) $(DL_PROTOCOL_H)
	find . -mindepth 2 -name Makefile -exec sh -c '$(MAKE) -C `dirname {}` $@' \; 
	find . -name '*~' -exec rm -f {} \;

dist_clean : clean


ab_clean:
	find sw/airborne -name '*~' -exec rm -f {} \;

test_all_example_airframes:
	$(MAKE) AIRCRAFT=BOOZ2_A2 clean_ac ap
	$(MAKE) AIRCRAFT=MJ5 clean_ac ap sim
	$(MAKE) AIRCRAFT=TJ1 clean_ac ap sim
	$(MAKE) AIRCRAFT=HITL clean_ac ap
	$(MAKE) AIRCRAFT=DM clean_ac ap sim
	$(MAKE) AIRCRAFT=CSC clean_ac ap
