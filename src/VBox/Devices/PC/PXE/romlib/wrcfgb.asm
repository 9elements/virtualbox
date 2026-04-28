; $Id: wrcfgb.asm 114041 2026-04-28 12:05:18Z knut.osmundsen@oracle.com $
;; @file
; PXE - VBox implementation of @pci_write_config_byte
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
; @pci_write_config_byte()
;
; int pci_write_config_byte(unsigned bus, unsigned dev,
;        unsigned func, unsigned reg, byte data)
;
;       Read a byte to the PCI configuration space
;
; passed:
;       AX, DX, BX := bus, device, function
;       stack := register, data
;
; returns:
;       Zero on success, non-zero on failure
;
; AX, DX, BX & flags trashed.  Other registers preserved.
;
public @pci_write_config_byte
@pci_write_config_byte proc near
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
        mov     cl,[bp+6]       ; load data byte to be written

        PCI_WRITE_BYTE          ; call PCI BIOS service

        mov     ax,0            ; set return code
        adc     ax,0

        ; Restore used registers and return.
        pop     cx
        pop     di
        pop     bp
        ret     4
@pci_write_config_byte endp

_TEXT   ENDS

        END
