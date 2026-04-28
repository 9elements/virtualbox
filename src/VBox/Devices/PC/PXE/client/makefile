# $Id: makefile 114041 2026-04-28 12:05:18Z knut.osmundsen@oracle.com $
## @file
# PXE - wmake makefile for client part and actual ROM.
#

#
# Copyright (C) 2008-2026 Oracle and/or its affiliates.
#
# This file is part of VirtualBox base platform packages, as
# available from https://www.virtualbox.org.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation, in version 3 of the
# License.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, see <https://www.gnu.org/licenses>.
#
# SPDX-License-Identifier: GPL-3.0-only
#

!include ../romcfg.mak
!include ../defrules.mak

INC_PATH = -I"../include"

LDFLAGS = sys dos com op quiet, map, nodef, stack=2k

CFLAGS += -D__FAR=_far -D__CDECL=_cdecl -DRELEASE_DEBUG

!ifeq DEBUG 1
CFLAGS += -DDEBUG=1
!endif

# Also look in subdir for sources
.c : pcnet

pxenic.bin : base.bin baseinit.bin undi.bin undiinit.bin
	cp undiinit.bin pxenic.bin
	..\tools\romcksum\romcksum -cksum=7 pxenic.bin
	..\tools\makerom\makerom -n pxenic.bin undi base
	# Take ROM size from file size and align to page boundary
	..\tools\romcksum\romcksum -cksum=7 -romsize=$$ -align=4k pxenic.bin


pxebase.bin : base.bin baseinit.bin
	cp baseinit.bin pxebase.bin
	..\tools\romcksum\romcksum -cksum=7 pxebase.bin
	..\tools\makerom\makerom -n pxebase.bin base
	..\tools\romcksum\romcksum -cksum=7 pxebase.bin

##

OBJS = 	__nul__.obj apientry.obj start.obj stop.obj ipboot.obj getbinl.obj unload.obj &
	tftpopen.obj tftpclos.obj tftpread.obj tftprdfl.obj tftpgfsz.obj udpopen.obj udpclose.obj &
	udpread.obj udpwrite.obj bis.obj bootp.obj bstrap.obj tftp.obj udp.obj arp.obj igmp.obj &
	et_calls.obj et_isr.obj iputilc.obj timeout.obj msg.obj misc.obj func.obj globals.obj

ROMLIB = ../romlib/rom.lib

base.bin : $(OBJS) $(ROMLIB)
	$(LD) $(LDFLAGS) name $@ file { $(OBJS) } library $(ROMLIB)

##

AFLAGS_INIT = -DINTEL

!ifeq DEBUG 1
AFLAGS_INIT += -DDEBUG=1
!else
AFLAGS_INIT += -DDEBUG=0
!endif

OBJS_INIT = init.obj

baseinit.bin : $(OBJS_INIT)
	$(LD) $(LDFLAGS) name $@ file { $(OBJS_INIT) }

##

AFLAGS_UINIT = -DMONOLITHIC=1

!ifeq DEBUG 1
AFLAGS_UINIT += -DDEBUG=1
!else
AFLAGS_UINIT += -DDEBUG=0
!endif

OBJS_UINIT = uinit.obj

undiinit.bin : $(OBJS_UINIT)
	$(LD) $(LDFLAGS) name $@ file { $(OBJS_UINIT) }

##

OBJS_UNDI = nic.obj undiapi.obj pcnet.obj e1000.obj net.obj

undi.bin : $(OBJS_UNDI) $(ROMLIB)
	$(LD) $(LDFLAGS) name $@ file { $(OBJS_UNDI) } library $(ROMLIB)

##

!include ../deftargs.mak
