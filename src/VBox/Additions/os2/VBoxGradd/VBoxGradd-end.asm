; $Id: VBoxGradd-end.asm 114081 2026-05-06 01:29:22Z knut.osmundsen@oracle.com $
;; @file
; VBoxGradd - Last file in the link.
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
%include "iprt/x86.mac"


%ifdef VBOXGRADD_COMPILED_WITH_WATCOM
segment _TEXT public CLASS=CODE align=1 use32 flat
%else
segment CODE32 public CLASS=CODE align=1 use32 flat
%endif

;;
; VAC308 does not do inline assembly, this is our ASMBitTest.
BEGINPROC VBoxBitTest
        push    ebp
        mov     ebp,esp
        push    edi

        mov     edi, [ebp+8] ; ptr
        mov     eax, [ebp+12]; bit

        bt      [edi], eax
        jnc     .not_set
        mov     eax, 1
        jmp     .bittestend
.not_set:
        mov     eax, 0
.bittestend:

        pop     edi
        pop     ebp
        ret
ENDPROC VBoxBitTest


;;
; Get the current CPL.
BEGINPROC VBoxGetCpl
        mov     ax, ss
        and     eax, 3
        ret
ENDPROC   VBoxGetCpl


;;
; Get the current IOPL.
BEGINPROC VBoxGetIopl
        pushfd
        pop     eax
        shr     eax, X86_EFL_IOPL_SHIFT
        and     eax, (X86_EFL_IOPL >> X86_EFL_IOPL_SHIFT)
        ret
ENDPROC   VBoxGetIopl


;;
; Output string to given port.
BEGINPROC VBoxOutByteString
        push    ebp
        mov     ebp, esp
        push    esi

        movzx   edx, word [ebp + 8]
        mov     esi, [ebp + 12]
        mov     ecx, [ebp + 16]
        cld
        rep outsb

        pop     esi
        leave
        ret
ENDPROC   VBoxOutByteString


%ifdef VBOXGRADD_COMPILED_WITH_VAC308
;
; HACK ALERT!
;
; VAC308 is unable to eliminate unused inlined functions during complication,
; it seems, so, just stub the symbols they reference and get on with it.  The
; linker does seem to eliminate the functions, but it still requires these
; symbols to be happy. sigh.
;
; HACK ALERT!
;
GLOBALNAME_RAW _RTLogGetDefaultInstance, function, default
GLOBALNAME_RAW _RTLogGetDefaultInstanceEx, function, default
GLOBALNAME_RAW _RTLogRelGetDefaultInstance, function, default
GLOBALNAME_RAW _RTLogRelGetDefaultInstanceEx, function, default
GLOBALNAME_RAW _RTLogLoggerExV, function, default
.again:
        int3
        jmp     .again
%endif

;
; Mark the end of the code segment (more or less).
;
GLOBALNAME_RAW EndOfCode, function, default
GLOBALNAME_RAW _EndOfCode, function, default


;
; End of shared data segment marker.
;
%ifdef VBOXGRADD_COMPILED_WITH_WATCOM
segment DATA_SHARED public CLASS=DATA_SHARED align=1 use32 flat
%else
segment DATA_SHARED public CLASS=DATA        align=1 use32 flat
%endif
%ifdef VBOXGRADD_COMPILED_WITH_VAC308
GLOBALNAME_RAW _fltused, data, default   ;; HACK ALERT! Referenced by RTErrConvertFromOS2 debug info.
%endif
GLOBALNAME_RAW g_EndOfData, data, default
GLOBALNAME_RAW _g_EndOfData, data, default

