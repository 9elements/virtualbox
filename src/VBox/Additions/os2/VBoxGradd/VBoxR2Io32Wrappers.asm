; $Id: VBoxR2Io32Wrappers.asm 114081 2026-05-06 01:29:22Z knut.osmundsen@oracle.com $
;; @file
; VBoxR2Lg - 32-bit wrapper code.
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
%ifdef VBOXGRADD_COMPILED_WITH_WATCOM
 %define RT_NOINC_SEGMENTS
%endif
%include "iprt/asmdefs.mac"


;*********************************************************************************************************************************
;*  Segment definitions.                                                                                                         *
;*********************************************************************************************************************************
segment CODE16      public CLASS=CODE align=1 use16
%ifdef VBOXGRADD_COMPILED_WITH_WATCOM
segment _TEXT       public CLASS=CODE align=1 use32 flat
 %define MYCODE32    _TEXT
 %macro MYBEGINCODE32 0
segment _TEXT
 %endmacro
%else
segment CODE32      public CLASS=CODE align=1 use32 flat
 %define MYCODE32    CODE32
 %macro MYBEGINCODE32 0
segment CODE32
 %endmacro
%endif

%ifdef VBOXGRADD_COMPILED_WITH_WATCOM
segment _DATA       public CLASS=DATA align=1 use32 flat
 %define MYDATA32   _DATA
%else
segment DATA32      public CLASS=DATA align=1 use32 flat
 %define MYDATA32   DATA32
%endif


;*********************************************************************************************************************************
;*  External Symbols                                                                                                             *
;*********************************************************************************************************************************

; 16-bit symbol
segment CODE16
extern    VBoxRing2OutU8

; 32-bit symbol
MYBEGINCODE32
extern DosFlatToSel


MYBEGINCODE32
;;
; 32-bit callable function.
;
; @cproto void __cdecl VBoxCallRing2OutU8Str(RTIOPORT uDst, const char *pch, size_t cch);
;
BEGINPROC VBoxCallRing2OutU8Str
        push    ebp
        mov     ebp, esp
        push    esi
        push    edi
        push    ebx

        ;
        ; Convert the stack to 16-bit.
        ; We leave LSS frame on the stack.
        ;
        mov     eax, esp
        push    ss                          ; old 32-bit SS
        push    eax                         ; old ESP
        mov     edi, esp                    ; Store the old stack pointer address in EDI.

        mov     eax, esp
        call    DosFlatToSel
        ; Check that we've got sufficient stack left in the segment.
        cmp     ax, 100h
        jae     .stack_okay

        and     esp, 0fffff00h
        sub     esp, 4h
        mov     eax, esp
        call    DosFlatToSel
.stack_okay:
        movzx   ecx, ax
        shr     eax, 16
        push    eax                         ; new 16-bit SS.
        push    ecx                         ; new ESP

        ;
        ; Load the parameters while the stack is still 32-bit.
        ;
        movzx   edx, word [ebp + 8 + 0]
        mov     esi, [ebp + 8 + 4]
        mov     ecx, [ebp + 8 + 8]

        ;
        ; Switch to 16-bit stack and code.
        ;
        lss     esp, [esp]

        ; jmp far dword VBoxOutByteStringInRing2_16code wrt CODE16
        db      066h
        db      0eah
        dw      .to_16bit_body wrt CODE16
        dw      CODE16
.end_of_32bit_head:

segment CODE16
.to_16bit_body:
        ;
        ; Call ring-2 code to output the string.
        ;

        ; Check if the string is empty before we start.
        test    ecx, ecx
        jz      .done

.byte_by_byte:
        movzx   eax, byte ds:[esi]
        inc     esi

        push    ax
        push    dx
        call far VBoxRing2OutU8

        dec     ecx
        jnz     .byte_by_byte
.done:

        ;
        ; Back to 32-bit.
        ;
        ;jmp far dword NAME(%i %+ _32) wrt FLAT
        db      066h
        db      0eah
%ifdef VBOXGRADD_COMPILED_WITH_WATCOM
        dd      .back_to_32bit_tail ; wrt FLAT
%else
        dd      .back_to_32bit_tail wrt MYCODE32
%endif
        dw      MYCODE32 wrt FLAT
.end_of_16bit_body:

MYBEGINCODE32
.back_to_32bit_tail:
        ;
        ; Restore stack and saved register, then return.
        ;
        lss     esp, [edi]
        pop     ebx
        pop     edi
        pop     esi
        leave
        ret
ENDPROC   VBoxCallRing2OutU8Str

