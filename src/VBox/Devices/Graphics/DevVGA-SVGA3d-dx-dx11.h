/* $Id: DevVGA-SVGA3d-dx-dx11.h 113456 2026-03-18 17:33:21Z vitali.pelenjow@oracle.com $ */
/** @file
 * DevSVGA - Internal DX11 backend utilities.
 */

/*
 * Copyright (C) 2020-2026 Oracle and/or its affiliates.
 *
 * This file is part of VirtualBox base platform packages, as
 * available from https://www.virtualbox.org.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation, in version 3 of the
 * License.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, see <https://www.gnu.org/licenses>.
 *
 * SPDX-License-Identifier: GPL-3.0-only
 */

#ifndef VBOX_INCLUDED_SRC_Graphics_DevVGA_SVGA3d_dx_dx11_h
#define VBOX_INCLUDED_SRC_Graphics_DevVGA_SVGA3d_dx_dx11_h
#ifndef RT_WITHOUT_PRAGMA_ONCE
# pragma once
#endif

#include <VBox/vmm/pdmdev.h>

#include "DevVGA-SVGA3d-internal.h"

/* d3d11_1.h has a structure field named 'Status' but Status is defined as int on Linux host */
#if defined(Status)
# undef Status
#endif
#ifndef RT_OS_WINDOWS
# pragma GCC diagnostic push
# pragma GCC diagnostic ignored "-Wpedantic"
#endif
#include <d3d11_1.h>
#ifndef RT_OS_WINDOWS
# pragma GCC diagnostic pop
#endif


/** @todo This is for RGB->I420 conversion. Make a generic OT object with target specific data and virtual methods. */
typedef struct DXTARGET2DUAV
{
    ID3D11Texture2D            *pT2D;
    ID3D11UnorderedAccessView  *pUAV;
    ID3D11Texture2D            *pT2DStaging;
} DXTARGET2DUAV;

typedef struct VMSVGAHWOUTPUTTARGET
{
    bool                        fReadingBack;

    ID3D11Query                *pReadbackQuery;

    ID3D11ComputeShader        *pCSy;
    ID3D11ComputeShader        *pCSuv;

    ID3D11Buffer               *pCSConstantBuffer;
    ID3D11SamplerState         *pSamplerState;

    DXGI_FORMAT                 enmPlaneFormat;

    DXTARGET2DUAV               y;
    DXTARGET2DUAV               u;
    DXTARGET2DUAV               v;

} VMSVGAHWOUTPUTTARGET;

int vmsvgaHwOutputTargetCreate(VMSVGAOUTPUTTARGET *pOutputTarget,
                               ID3D11Device1 *pDevice);
void vmsvgaHwOutputTargetDestroy(VMSVGAOUTPUTTARGET *pOutputTarget);
int vmsvgaHwOutputTargetConvert(VMSVGAOUTPUTTARGET *pOutputTarget,
                                ID3D11DeviceContext1 *pDeviceContext,
                                ID3D11ShaderResourceView *pSrcSrv,
                                UINT srcW, UINT srcH);
int vmsvgaHwOutputTargetCheckCompletion(VMSVGAOUTPUTTARGET *pOutputTarget,
                                        ID3D11DeviceContext1 *pDeviceContext);
int vmsvgaHwOutputTargetReadback(VMSVGAOUTPUTTARGET *pOutputTarget,
                                 ID3D11DeviceContext1 *pDeviceContext);

#endif /* !VBOX_INCLUDED_SRC_Graphics_DevVGA_SVGA3d_dx_dx11_h */
