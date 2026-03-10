; $Id: security-cookie-vcc.asm 113304 2026-03-10 15:19:22Z knut.osmundsen@oracle.com $
;; @file
; IPRT - Stack related Visual C++ support routines, ring-0.
;

;
; Copyright (C) 2022-2026 Oracle and/or its affiliates.
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
; The contents of this file may alternatively be used under the terms
; of the Common Development and Distribution License Version 1.0
; (CDDL), a copy of it is provided in the "COPYING.CDDL" file included
; in the VirtualBox distribution, in which case the provisions of the
; CDDL are applicable instead of those of the GPL.
;
; You may elect to license modified versions of this file under the
; terms and conditions of either the GPL or the CDDL or both.
;
; SPDX-License-Identifier: GPL-3.0-only OR CDDL-1.0
;


;*********************************************************************************************************************************
;*  Header Files                                                                                                                 *
;*********************************************************************************************************************************
%define RT_ASM_WITH_SEH64_ALT
%include "iprt/asmdefs.mac"


;*********************************************************************************************************************************
;*  Defined Constants And Macros                                                                                                 *
;*********************************************************************************************************************************
;; The default security cookie.
; Can be re-defined via ASDEFS.
%ifndef  RT_VCC_SECURITY_COOKIE_DEFAULT_LOW
 %define RT_VCC_SECURITY_COOKIE_DEFAULT_LOW     0xdeadbeef
%endif
%ifndef  RT_VCC_SECURITY_COOKIE_DEFAULT_HIGH
 %define RT_VCC_SECURITY_COOKIE_DEFAULT_HIGH    0x0c00ffe0
%endif

;; The what we XOR the RDTSC output with when initializing the cookie.
; Can be re-defined via ASDEFS.
%ifndef  RT_VCC_SECURITY_COOKIE_XOR_LOW
 %define RT_VCC_SECURITY_COOKIE_XOR_LOW         0xc22f3ec7
%endif
%ifndef  RT_VCC_SECURITY_COOKIE_XOR_HIGH
 %define RT_VCC_SECURITY_COOKIE_XOR_HIGH        0x4ab98ec4
%endif


;*********************************************************************************************************************************
;*  Global Variables                                                                                                             *
;*********************************************************************************************************************************
BEGINDATA
GLOBALNAME __security_cookie
        dd  RT_VCC_SECURITY_COOKIE_DEFAULT_LOW
        dd  RT_VCC_SECURITY_COOKIE_DEFAULT_HIGH
GLOBALNAME __security_cookie_complement
        dd  ~(RT_VCC_SECURITY_COOKIE_DEFAULT_LOW)  & 0xffffffff
        dd  ~(RT_VCC_SECURITY_COOKIE_DEFAULT_HIGH) & 0xffffffff


;;
; Initializes the security cookie.
;
; @cproto void __cdecl __security_init_cookie(void);
;
BEGINPROC __security_init_cookie
        push    xBP
        SEH64_PUSH_xBP
        mov     xBP, xSP
        SEH64_SET_FRAME_xBP 0
        SEH64_END_PROLOGUE

        ; Don't initialize it again if already done.
        cmp     dword [NAME(__security_cookie) xWrtRIP], RT_VCC_SECURITY_COOKIE_DEFAULT_LOW
        je      .need_init
        cmp     dword [NAME(__security_cookie) + 4 xWrtRIP], RT_VCC_SECURITY_COOKIE_DEFAULT_HIGH
        jne     .already_initialized

        ; Use TSC to get a random-ish number.
.need_init:
        rdtsc

        ; XOR with random number.
        xor     eax, RT_VCC_SECURITY_COOKIE_XOR_LOW
        xor     edx, RT_VCC_SECURITY_COOKIE_XOR_HIGH

        ; Let KASLR do some work.
        lea     xCX, [NAME(__security_cookie) + 4 xWrtRIP]
        xor     eax, ecx
        xor     edx, esp

        ; Store the result.
.store_result:
        mov     [NAME(__security_cookie) xWrtRIP], eax
        mov     [NAME(__security_cookie) + 4 xWrtRIP], edx

        not     eax
        not     edx
        mov     [NAME(__security_cookie_complement) xWrtRIP], eax
        mov     [NAME(__security_cookie_complement) + 4 xWrtRIP], edx

.already_initialized:
        leave
        ret
ENDPROC   __security_init_cookie

