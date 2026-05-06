; $Id: VBoxGradd-begin.asm 114081 2026-05-06 01:29:22Z knut.osmundsen@oracle.com $
;; @file
; VBoxGradd - First file in the link.
;

;
; Copyright (C) 2007-2026 Oracle and/or its affiliates.
;
; This file is part of VirtualBox base platform packages, as
; available from https://www.virtualbox.org.
;
; This program is free software; you can redistribute it and/or
; modify it under the terms of the GNU General Public License
; as published by the Free Software Foundation, in version 3 of the
; License.
;
; This program is distributed in the hope that it will be useful, but
; WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
; General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program; if not, see <https://www.gnu.org/licenses>.
;
; SPDX-License-Identifier: GPL-3.0-only
;


;*********************************************************************************************************************************
;*  Header Files                                                                                                                 *
;*********************************************************************************************************************************
%define RT_NOINC_SEGMENTS
%include "iprt/asmdefs.mac"

;
; Start of code segment marker.
;
%ifdef VBOXGRADD_COMPILED_WITH_WATCOM
segment _TEXT       public CLASS=CODE align=1 use32 flat
%else
segment CODE32      public CLASS=CODE align=1 use32 flat
%endif
GLOBALNAME_RAW StartOfCode, function, default
GLOBALNAME_RAW _StartOfCode, function, default

;
; Start of shared data segment marker.
;
%ifdef VBOXGRADD_COMPILED_WITH_WATCOM
segment DATA_SHARED public CLASS=DATA_SHARED align=1 use32 flat
%else
segment DATA_SHARED public CLASS=DATA        align=1 use32 flat
%endif
GLOBALNAME_RAW g_StartOfData, data, default
GLOBALNAME_RAW _g_StartOfData, data, default

