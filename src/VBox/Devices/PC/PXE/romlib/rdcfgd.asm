; $Id: rdcfgd.asm 114041 2026-04-28 12:05:18Z knut.osmundsen@oracle.com $
;; @file
; PXE - VBox implementation of @pci_read_config_dword
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
; @pci_read_config_dword()
;
; int pci_read_config_dword(unsigned bus, unsigned dev,
;        unsigned func, unsigned reg, dword *p_data)
;
;       Read a byte from PCI configuration space
;
; passed:
;       AX, DX, BX := bus, device, function
;       stack := register, near pointer to data
;
; returns:
;       Zero on success, non-zero on failure
;
; AX, DX, BX & flags trashed.  Other registers preserved.
;
public @pci_read_config_dword
@pci_read_config_dword proc near
        ; Save used registers.
        push    bp
        mov     bp, sp
        push    di
        push    cx

        ; Call PCI BIOS.
        mov     bh,al           ; bus number
        shl     dl,3            ; device number
        or      bl,dl           ; or with function
        mov     di,[bp+4]       ; offset into config space (register no.)

        PCI_READ_DWORD          ; call PCI BIOS service

        mov     ax,0            ; set return code
        adc     ax,0

        mov     di,[bp+6]       ; load destination address
        mov     [di],ecx        ; store dword read from config space

        ; Restore used registers and return.
        pop     cx
        pop     di
        pop     bp
        ret     4
@pci_read_config_dword endp

_TEXT   ENDS

        END
