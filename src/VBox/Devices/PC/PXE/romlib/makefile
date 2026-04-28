# $Id: makefile 114041 2026-04-28 12:05:18Z knut.osmundsen@oracle.com $
## @file
# PXE - wmake makefile for the ROM library code.
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

!ifeq DEBUG 1
CFLAGS += -DDEBUG=1
!endif

OBJS = 	putc.obj puts.obj puth1.obj puth2.obj puth4.obj puth8.obj &
	putip.obj putu16.obj putu32.obj put_uuid.obj cksum.obj findtabl.obj sm_dmi.obj is_uuid.obj finduuid.obj &
	kbhit.obj getc.obj getrow.obj getcol.obj gotorc.obj getrows.obj getcols.obj &
	ia64.obj extmemsz.obj bigmemsz.obj extmem2.obj extmem3.obj memmap.obj sysmap.obj &
	cll.obj cls.obj strlen.obj strcpy.obj strcat.obj strcmp.obj stricmp.obj strncmp.obj strncpy.obj &
	hinit.obj halloc.obj hfree.obj isheap.obj xms.obj xmsc.obj &
	setjmp.obj longjmp.obj longswap.obj intswap.obj reboot.obj timer.obj &
	magik.obj zerohw.obj dhcpread.obj dhcpwrit.obj dhcpvend.obj dhcpcmn.obj &
	fbms.obj _cs.obj _ds.obj _ss.obj _sp.obj &
	rdcfgb.obj rdcfgw.obj rdcfgd.obj wrcfgb.obj finddev.obj findclas.obj &
	i4m.obj i4d.obj &
	fmemcpy.obj fmemset.obj fmemcmp.obj fmemicmp.obj &
	dputs.obj dputc.obj dputip.obj dputh1.obj dputh2.obj dputh4.obj &
	dputh8.obj dputu16.obj dputu32.obj
#	anldiv.obj anlmul.obj anulrem.obj anuldiv.obj anlshl.obj anlshr.obj anulshr.obj

rom.lib : $(OBJS)
	%create $^&.lbc
	@for %i in ($(OBJS)) do @%append $^&.lbc +%i
	$(LIB) $(LIBFLAGS) $@ @$^&.lbc

i4m.obj :
	wlib -q $(%WATCOM)\lib286\dos\clibs.lib *i4m

i4d.obj :
	wlib -q $(%WATCOM)\lib286\dos\clibs.lib *i4d

!include ../deftargs.mak
