; $Id: findclas.asm 114041 2026-04-28 12:05:18Z knut.osmundsen@oracle.com $
;; @file
; PXE - VBox implementation of @pci_find_class
;

;
; Copyright (C) 2008-2026 Oracle and/or its affiliates.
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

include segdefs.inc
include pci.inc

.386

_TEXT   SEGMENT
        ASSUME  CS:_TEXT

;;
; @pci_find_class()
;
; int unsigned pci_find_class(unsigned base_class,
;     unsigned sub_class, unsigned prog_intf,  unsigned index,
;     unsigned char *p_bus, unsigned char *p_dev, unsigned char *p_func);
; int unsigned pci_find_device(unsigned vendor, unsigned device,
;     unsigned index, unsigned char *p_bus, unsigned char *p_dev,
;     unsigned char *p_func);
;
;       Find a PCI device of specified class
;
; passed:
;       AX, DX, BX := base class, sub-class, interface
;       stack := index, near pointers to data bus, device, function
;
; returns:
;       One (TRUE) if specified device found, zero (FALSE) otherwise;
;       p_bus/p_dev/p_func are filled in if they are not NULL.
;
; AX, DX, BX & flags trashed.  Other registers preserved.
;
public @pci_find_class
@pci_find_class proc near
        ; Save used registers.
        push    bp
        mov     bp, sp
        push    ecx
        push    si

        ; Call PCI BIOS.
        xor     ecx,ecx
        mov     ch,al           ; base class
        mov     cl,dl           ; sub-class
        shl     ecx,8
        mov     cl,bl           ; interface
        mov     si,[bp+4]       ; index

        stc                     ; pre-set CF to simplify error checking
        mov     ax,0B103h
        int     1Ah             ; call PCI BIOS service

        mov     ax,0            ; calculate return value
        sbb     ax,0
        inc     ax
        mov     dx,bx           ; save bus/dev/fn

        mov     bx,[bp+6]       ; load bus destination address
        test    bx,bx           ; check for NULL
        jz      @F
        mov     [bx],dh         ; write bus #
@@:
        mov     bx,[bp+8]       ; load device destination address
        test    bx,bx           ; check for NULL
        jz      @F
        mov     [bx],dl         ; write device #
        shr     byte ptr [bx],3
@@:
        mov     bx,[bp+10]      ; load functions destination address
        test    bx,bx           ; check for NULL
        jz      @F
        mov     [bx],dl         ; write function #
        and     byte ptr [bx],7
@@:

        ; Restore used registers and return.
        pop     si
        pop     ecx
        pop     bp
        ret     8
@pci_find_class endp

_TEXT   ENDS

        END
