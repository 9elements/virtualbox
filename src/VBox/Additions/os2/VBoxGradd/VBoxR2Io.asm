; $Id: VBoxR2Io.asm 114081 2026-05-06 01:29:22Z knut.osmundsen@oracle.com $
;; @file
; VBoxR2Io - I/O via ring-3.
;

;
; Copyright (C) 2026 Oracle and/or its affiliates.
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

%define NAME(x) x

segment CODE16_IOPL public CLASS=CODE align=1 use16

;;
; @cproto   void __cdecl VBoxRing2OutU8(uint16_t uPort, uint8_t bValue);
; @clobbers none except flags
BEGINPROC VBoxRing2OutU8
        push    ebp
        mov     bp, sp
        push    eax
        push    edx

        mov     dx, [bp + 4 + 4]
        mov     al, [bp + 4 + 6]
        out     dx, al

        pop     edx
        pop     eax
        pop     ebp
        retf    4
ENDPROC   VBoxRing2OutU8


;;
; @cproto   void __cdecl VBoxRing2OutU16(uint16_t uPort, uint16_t uValue);
; @clobbers none except flags
BEGINPROC VBoxRing2OutU16
        push    ebp
        mov     bp, sp
        push    eax
        push    edx

        mov     dx, [bp + 4 + 4]
        mov     ax, [bp + 4 + 6]
        out     dx, ax

        pop     edx
        pop     eax
        pop     ebp
        retf    4
ENDPROC   VBoxRing2OutU16


;;
; @cproto   void __cdecl VBoxRing2OutU32(uint16_t uPort, uint32_t uValue);
; @clobbers none except flags
BEGINPROC VBoxRing2OutU32
        push    ebp
        mov     bp, sp
        push    eax
        push    edx

        mov     dx, [bp + 4 + 4]
        mov     eax, [bp + 4 + 6]
        out     dx, eax

        pop     edx
        pop     eax
        pop     ebp
        retf    6
ENDPROC   VBoxRing2OutU32


%if 0 ; untested use byte primitive instead.
;;
; @cproto   void __cdecl VBoxRing2OutU8Str(uint16_t uPort, uint8_t __far *pb, uint16_t cb);
; @clobbers none except flags
BEGINPROC VBoxRing2OutU8Str
        push    ebp
        mov     bp, sp
        push    eax
        push    edx
        push    esi
        push    ds

        mov     dx, [bp + 4 + 4]
        lds     si, [bp + 4 + 4 + 2]
        mov     cx, [bp + 4 + 4 + 4]
        cld
        rep outsb

        pop     ds
        pop     esi
        pop     edx
        pop     eax
        pop     ebp
        retf    8
ENDPROC   VBoxRing2OutU8Str
%endif
