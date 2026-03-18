/* $Id: DevVGA-SVGA3d-dx-dx11-output.cpp 113456 2026-03-18 17:33:21Z vitali.pelenjow@oracle.com $ */
/** @file
 * DevSVGA - D3D11 backend graphics output utilities
 */

/*
 * Copyright (C) 2026 Oracle and/or its affiliates.
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

#define LOG_GROUP LOG_GROUP_DEV_VMSVGA

#include <VBox/log.h>

#include <iprt/mem.h>

#ifdef RT_OS_WINDOWS
# include <iprt/win/windows.h>
#endif

#include "DevVGA-SVGA3d-dx-dx11.h "

/* Output target transforms entire ScreenTexture and copies the result to a memory buffer.
 *
 * Steps:
 *   * Render (optional): screen texture -> output texture(s)
 *   * Copy (optional): output texture(s) -> staging texture(s)
 *   * Query: wait on a query for completion
 *   * Readback (optional): staging texture(s) -> memory buffers(s)
 *
 */

#include "shaders/d3d11yuv.hlsl.cs_y.h"
#include "shaders/d3d11yuv.hlsl.cs_uv.h"

/* Compute shader parameters for YUV conversion. */
struct CSParameters
{
    /* Destination Y plane dimensions. */
    UINT dstW;
    UINT dstH;
    UINT pad0;
    UINT pad1;

    /* Offset of the scaled input image in the Y plane in output pixels */
    float dstOffX;
    float dstOffY;
    /* 1/scaledW, 1/scaledH */
    float invScaledW;
    float invScaledH;
};


static void computeCSParameters(struct CSParameters *p, UINT srcW, UINT srcH, UINT dstW, UINT dstH)
{
    p->dstW = dstW;
    p->dstH = dstH;

    float scale;
    if (srcW <= dstW && srcH <= dstH)
        scale = 1.0f;
    else
    {
        float const scaleX = (float)dstW / (float)srcW;
        float const scaleY = (float)dstH / (float)srcH;
        scale = RT_MIN(scaleX, scaleY);
    }

    float const scaledW = (float)srcW * scale;
    float const scaledH = (float)srcH * scale;

    p->dstOffX = 0.5f * ((float)dstW - scaledW);
    p->dstOffY = 0.5f * ((float)dstH - scaledH);

    p->invScaledW = 1.0f / scaledW;
    p->invScaledH = 1.0f / scaledH;
}


static void dxTarget2DUAVCleanup(DXTARGET2DUAV *p)
{
    D3D_RELEASE(p->pT2DStaging);
    D3D_RELEASE(p->pUAV);
    D3D_RELEASE(p->pT2D);
}


static void dxOutputTargetCleanup(VMSVGAHWOUTPUTTARGET *pHwOutputTarget)
{
    dxTarget2DUAVCleanup(&pHwOutputTarget->v);
    dxTarget2DUAVCleanup(&pHwOutputTarget->u);
    dxTarget2DUAVCleanup(&pHwOutputTarget->y);

    D3D_RELEASE(pHwOutputTarget->pSamplerState);
    D3D_RELEASE(pHwOutputTarget->pCSConstantBuffer);
    D3D_RELEASE(pHwOutputTarget->pCSuv);
    D3D_RELEASE(pHwOutputTarget->pCSy);
    D3D_RELEASE(pHwOutputTarget->pReadbackQuery);
}


static bool dxFormatSupportsTypedUAV(ID3D11Device1 *pDevice, DXGI_FORMAT dxgiFormat)
{
    UINT FormatSupport = 0;
    if (FAILED(pDevice->CheckFormatSupport(dxgiFormat, &FormatSupport)))
        return false;

    return RT_BOOL(FormatSupport & D3D11_FORMAT_SUPPORT_TYPED_UNORDERED_ACCESS_VIEW);
}


static DXGI_FORMAT dxChooseYUVPlaneFormat(ID3D11Device1 *pDevice)
{
    if (dxFormatSupportsTypedUAV(pDevice, DXGI_FORMAT_R8_UNORM))
        return DXGI_FORMAT_R8_UNORM;

    if (dxFormatSupportsTypedUAV(pDevice, DXGI_FORMAT_R16_UNORM))
        return DXGI_FORMAT_R16_UNORM;

    return DXGI_FORMAT_UNKNOWN;
}


static HRESULT dxTarget2DUAVCreate(ID3D11Device1 *pDevice,
                                   uint32_t cWidth,
                                   uint32_t cHeight,
                                   DXGI_FORMAT dxgiFormat,
                                   DXTARGET2DUAV *pPlane)
{
    D3D11_TEXTURE2D_DESC texDesc;
    RT_ZERO(texDesc);
    texDesc.Width            = cWidth;
    texDesc.Height           = cHeight;
    texDesc.MipLevels        = 1;
    texDesc.ArraySize        = 1;
    texDesc.Format           = dxgiFormat;
    texDesc.SampleDesc.Count = 1;
    texDesc.Usage            = D3D11_USAGE_DEFAULT;
    texDesc.BindFlags        = D3D11_BIND_UNORDERED_ACCESS | D3D11_BIND_SHADER_RESOURCE;

    HRESULT hr = pDevice->CreateTexture2D(&texDesc, NULL, &pPlane->pT2D);
    AssertReturn(SUCCEEDED(hr), hr);

    D3D11_UNORDERED_ACCESS_VIEW_DESC uavDesc;
    RT_ZERO(uavDesc);
    uavDesc.Format             = texDesc.Format;
    uavDesc.ViewDimension      = D3D11_UAV_DIMENSION_TEXTURE2D;
    uavDesc.Texture2D.MipSlice = 0;

    hr = pDevice->CreateUnorderedAccessView(pPlane->pT2D, &uavDesc, &pPlane->pUAV);
    AssertReturn(SUCCEEDED(hr), hr);

    texDesc.Usage          = D3D11_USAGE_STAGING;
    texDesc.BindFlags      = 0;
    texDesc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;

    hr = pDevice->CreateTexture2D(&texDesc, NULL, &pPlane->pT2DStaging);
    AssertReturn(SUCCEEDED(hr), hr);

    return S_OK;
}


int vmsvgaHwOutputTargetCreate(VMSVGAOUTPUTTARGET *pOutputTarget,
                               ID3D11Device1 *pDevice)
{
    HRESULT hr;

    uint32_t const cWidth = pOutputTarget->desc.cWidth;
    uint32_t const cHeight = pOutputTarget->desc.cHeight;

    /* Texture dimensions must be a multiple of 2. */
    AssertReturn(cWidth > 0 && cHeight > 0, VERR_INVALID_PARAMETER);
    AssertReturn(   cWidth <= D3D11_REQ_TEXTURE2D_U_OR_V_DIMENSION
                 && cHeight <= D3D11_REQ_TEXTURE2D_U_OR_V_DIMENSION, VERR_INVALID_PARAMETER);
    AssertReturn((cWidth & 1) == 0 && (cHeight & 1) == 0, VERR_INVALID_PARAMETER);

    /* R8_UNORM (preferrable) or R16_UNORM. */
    DXGI_FORMAT const dxgiFormatPlane = dxChooseYUVPlaneFormat(pDevice);
    AssertReturn(dxgiFormatPlane != DXGI_FORMAT_UNKNOWN, VERR_NOT_SUPPORTED);

    Assert(pOutputTarget->pHwOutputTarget == NULL);

    VMSVGAHWOUTPUTTARGET *pHwOutputTarget = (VMSVGAHWOUTPUTTARGET *)RTMemAllocZ(sizeof(*pHwOutputTarget));
    AssertPtrReturn(pHwOutputTarget, VERR_NO_MEMORY);

    /* The caller will do a cleanup on failure. */
    pOutputTarget->pHwOutputTarget = pHwOutputTarget;

    pHwOutputTarget->enmPlaneFormat  = dxgiFormatPlane;
    pHwOutputTarget->fReadingBack    = false;

    /* A query to indicate completion of conversion. */
    D3D11_QUERY_DESC queryDesc;
    RT_ZERO(queryDesc);
    queryDesc.Query = D3D11_QUERY_EVENT;

    hr = pDevice->CreateQuery(&queryDesc, &pHwOutputTarget->pReadbackQuery);
    AssertReturn(SUCCEEDED(hr), VERR_NO_MEMORY);

    /* Compute shaders. */
    hr = pDevice->CreateComputeShader(g_cs_y, sizeof(g_cs_y), NULL, &pHwOutputTarget->pCSy);
    AssertReturn(SUCCEEDED(hr), VERR_NO_MEMORY);
    hr = pDevice->CreateComputeShader(g_cs_uv, sizeof(g_cs_uv), NULL, &pHwOutputTarget->pCSuv);
    AssertReturn(SUCCEEDED(hr), VERR_NO_MEMORY);

    /* Constant buffer for compute shaders. */
    D3D11_BUFFER_DESC constantBufferDesc;
    RT_ZERO(constantBufferDesc);
    constantBufferDesc.ByteWidth      = RT_ALIGN_32(sizeof(CSParameters), 16);
    constantBufferDesc.Usage          = D3D11_USAGE_DYNAMIC;
    constantBufferDesc.BindFlags      = D3D11_BIND_CONSTANT_BUFFER;
    constantBufferDesc.CPUAccessFlags = D3D11_CPU_ACCESS_WRITE;

    hr = pDevice->CreateBuffer(&constantBufferDesc, NULL, &pHwOutputTarget->pCSConstantBuffer);
    AssertReturn(SUCCEEDED(hr), VERR_NO_MEMORY);

    /* Linear clamp sampler for scaling. */
    D3D11_SAMPLER_DESC samplerDesc;
    RT_ZERO(samplerDesc);
    samplerDesc.Filter         = D3D11_FILTER_MIN_MAG_MIP_LINEAR;
    samplerDesc.AddressU       = D3D11_TEXTURE_ADDRESS_CLAMP;
    samplerDesc.AddressV       = D3D11_TEXTURE_ADDRESS_CLAMP;
    samplerDesc.AddressW       = D3D11_TEXTURE_ADDRESS_CLAMP;
    samplerDesc.MaxAnisotropy  = 1;
    samplerDesc.ComparisonFunc = D3D11_COMPARISON_ALWAYS;

    hr = pDevice->CreateSamplerState(&samplerDesc, &pHwOutputTarget->pSamplerState);
    AssertReturn(SUCCEEDED(hr), VERR_NO_MEMORY);

    /* Textures for Y, U, V planes. */
    hr = dxTarget2DUAVCreate(pDevice, cWidth, cHeight, dxgiFormatPlane, &pHwOutputTarget->y);
    AssertReturn(SUCCEEDED(hr), VERR_NO_MEMORY);
    hr = dxTarget2DUAVCreate(pDevice, cWidth / 2, cHeight / 2, dxgiFormatPlane, &pHwOutputTarget->u);
    AssertReturn(SUCCEEDED(hr), VERR_NO_MEMORY);
    hr = dxTarget2DUAVCreate(pDevice, cWidth / 2, cHeight / 2, dxgiFormatPlane, &pHwOutputTarget->v);
    AssertReturn(SUCCEEDED(hr), VERR_NO_MEMORY);

    return VINF_SUCCESS;
}


void vmsvgaHwOutputTargetDestroy(VMSVGAOUTPUTTARGET *pOutputTarget)
{
    AssertReturnVoid(pOutputTarget);

    if (!pOutputTarget->pHwOutputTarget)
        return;

    dxOutputTargetCleanup(pOutputTarget->pHwOutputTarget);
    RTMemFree(pOutputTarget->pHwOutputTarget);
    pOutputTarget->pHwOutputTarget = NULL;
}


int vmsvgaHwOutputTargetConvert(VMSVGAOUTPUTTARGET *pOutputTarget,
                                ID3D11DeviceContext1 *pDeviceContext,
                                ID3D11ShaderResourceView *pSrcSrv,
                                UINT srcW, UINT srcH)
{
    HRESULT hr;

    AssertReturn(pOutputTarget && pOutputTarget->pHwOutputTarget, VERR_INVALID_PARAMETER);
    AssertReturn(pDeviceContext, VERR_INVALID_PARAMETER);
    AssertReturn(pSrcSrv, VERR_INVALID_PARAMETER);

    /* Save/restore pipeline state.
     * Shader, shader resource and UAVs are set by setupPipeline.
     */
    /** @todo Update after state tracking redesign. */
    ID3D11Buffer *pSavedConstantBuffer;
    pDeviceContext->CSGetConstantBuffers(0, 1, &pSavedConstantBuffer);
    ID3D11SamplerState *pSavedSamplerState;
    pDeviceContext->CSGetSamplers(0, 1, &pSavedSamplerState);

    VMSVGAHWOUTPUTTARGET *pHwOutputTarget = pOutputTarget->pHwOutputTarget;

    /* Update compute shader parameters. */
    D3D11_MAPPED_SUBRESOURCE mapped;
    hr = pDeviceContext->Map(pHwOutputTarget->pCSConstantBuffer, 0, D3D11_MAP_WRITE_DISCARD, 0, &mapped);
    AssertReturn(SUCCEEDED(hr), VERR_INTERNAL_ERROR);

    CSParameters *pParams = (CSParameters *)mapped.pData;
    computeCSParameters(pParams, srcW, srcH, pOutputTarget->desc.cWidth, pOutputTarget->desc.cHeight);

    pDeviceContext->Unmap(pHwOutputTarget->pCSConstantBuffer, 0);

    /* Invoke compute shaders to convert source to destination planes. */
    ID3D11UnorderedAccessView *apUav[2] = { NULL, NULL };
    UINT uInitialCounts[2] = { 0, 0 };

    /* Dispatch the luminance pass. */
    pDeviceContext->CSSetShader(pHwOutputTarget->pCSy, NULL, 0);
    pDeviceContext->CSSetConstantBuffers(0, 1, &pHwOutputTarget->pCSConstantBuffer);
    pDeviceContext->CSSetShaderResources(0, 1, &pSrcSrv);
    pDeviceContext->CSSetSamplers(0, 1, &pHwOutputTarget->pSamplerState);
    apUav[0] = pHwOutputTarget->y.pUAV;
    pDeviceContext->CSSetUnorderedAccessViews(0, 1, apUav, uInitialCounts);

    UINT const cGroupXy = (pOutputTarget->desc.cWidth + 15) / 16;
    UINT const cGroupYy = (pOutputTarget->desc.cHeight + 15) / 16;
    pDeviceContext->Dispatch(cGroupXy, cGroupYy, 1);

    /* Unbind UAV before reusing the slot (seems to be a good practice). */
    apUav[0] = NULL;
    pDeviceContext->CSSetUnorderedAccessViews(0, 1, apUav, uInitialCounts);

    /* Dispatch the chroma pass. */
    pDeviceContext->CSSetShader(pHwOutputTarget->pCSuv, NULL, 0);
    //pDeviceContext->CSSetConstantBuffers(0, 1, &pHwOutputTarget->pCSConstantBuffer);
    //pDeviceContext->CSSetShaderResources(0, 1, &pSrcSrv);
    pDeviceContext->CSSetSamplers(0, 1, &pHwOutputTarget->pSamplerState);
    apUav[0] = pHwOutputTarget->u.pUAV;
    apUav[1] = pHwOutputTarget->v.pUAV;
    pDeviceContext->CSSetUnorderedAccessViews(0, 2, apUav, NULL);

    /* U/V pass operates on half resolution. */
    UINT const cGroupXuv = ((pOutputTarget->desc.cWidth / 2) + 15) / 16;
    UINT const cGroupYuv = ((pOutputTarget->desc.cHeight / 2) + 15) / 16;
    pDeviceContext->Dispatch(cGroupXuv, cGroupYuv, 1);

    /* Unbind all compute shader state. */
    pDeviceContext->CSSetShader(NULL, NULL, 0);
    ID3D11Buffer *apNullBuffer[] = { NULL };
    pDeviceContext->CSSetConstantBuffers(0, RT_ELEMENTS(apNullBuffer), apNullBuffer);
    ID3D11ShaderResourceView *apNullSrv[] = { NULL };
    pDeviceContext->CSSetShaderResources(0, RT_ELEMENTS(apNullSrv), apNullSrv);
    ID3D11SamplerState *apNullSampler[] = { NULL };
    pDeviceContext->CSSetSamplers(0, RT_ELEMENTS(apNullSampler), apNullSampler);
    apUav[0] = NULL;
    apUav[1] = NULL;
    pDeviceContext->CSSetUnorderedAccessViews(0, 2, apUav, uInitialCounts);

    pDeviceContext->CSSetConstantBuffers(0, 1, &pSavedConstantBuffer);
    D3D_RELEASE(pSavedConstantBuffer);
    pDeviceContext->CSSetSamplers(0, 1, &pSavedSamplerState);
    D3D_RELEASE(pSavedSamplerState);

    /* Copy results into staging textures for CPU read-back. */
    pDeviceContext->CopyResource(pHwOutputTarget->y.pT2DStaging, pHwOutputTarget->y.pT2D);
    pDeviceContext->CopyResource(pHwOutputTarget->u.pT2DStaging, pHwOutputTarget->u.pT2D);
    pDeviceContext->CopyResource(pHwOutputTarget->v.pT2DStaging, pHwOutputTarget->v.pT2D);

    pDeviceContext->Flush();

    pDeviceContext->End(pHwOutputTarget->pReadbackQuery);

    return VINF_SUCCESS;
}


int vmsvgaHwOutputTargetCheckCompletion(VMSVGAOUTPUTTARGET *pOutputTarget,
                                        ID3D11DeviceContext1 *pDeviceContext)
{
    VMSVGAHWOUTPUTTARGET *pHwOutputTarget = pOutputTarget->pHwOutputTarget;

    BOOL fDone = FALSE;
    HRESULT hr = pDeviceContext->GetData(pHwOutputTarget->pReadbackQuery, &fDone, sizeof(fDone),
                                         D3D11_ASYNC_GETDATA_DONOTFLUSH);
    AssertReturn(SUCCEEDED(hr), VERR_NOT_SUPPORTED);

    if (hr == S_FALSE || !fDone)
        return VERR_TRY_AGAIN;

    return VINF_SUCCESS;
}


static int vmsvgaHwOutputTargetCopyPlane(ID3D11DeviceContext1 *pDeviceContext,
                                         ID3D11Texture2D *pStagingTexture,
                                         uint32_t cWidth,
                                         uint32_t cHeight,
                                         DXGI_FORMAT enmPlaneFormat,
                                         uint8_t *pu8Dst)
{
    D3D11_MAPPED_SUBRESOURCE mapped;
    HRESULT hr = pDeviceContext->Map(pStagingTexture, 0, D3D11_MAP_READ, 0, &mapped);
    AssertReturn(SUCCEEDED(hr), VERR_NOT_SUPPORTED);

    uint8_t const *pu8Src = (uint8_t const *)mapped.pData;

    if (enmPlaneFormat == DXGI_FORMAT_R8_UNORM)
    {
        for (uint32_t y = 0; y < cHeight; ++y)
        {
            memcpy(pu8Dst, pu8Src, cWidth);

            pu8Dst += cWidth;
            pu8Src += mapped.RowPitch;
        }
    }
    else if (enmPlaneFormat == DXGI_FORMAT_R16_UNORM)
    {
        for (uint32_t y = 0; y < cHeight; ++y)
        {
            uint16_t const *pu16Src = (uint16_t const *)pu8Src;

            for (uint32_t x = 0; x < cWidth; ++x)
            {
                uint32_t const u32 = pu16Src[x]; /* Use uint32_t to avoid a theoretical overflow from +128. */
                pu8Dst[x] = (uint8_t)((u32 + 128) >> 8);
            }

            pu8Dst += cWidth;
            pu8Src += mapped.RowPitch;
        }
    }
    else
        AssertFailed();

    pDeviceContext->Unmap(pStagingTexture, 0);

    return VINF_SUCCESS;
}


int vmsvgaHwOutputTargetReadback(VMSVGAOUTPUTTARGET *pOutputTarget,
                                 ID3D11DeviceContext1 *pDeviceContext)
{
    VMSVGAHWOUTPUTTARGET *pHwOutputTarget = pOutputTarget->pHwOutputTarget;

    AssertReturn(   pHwOutputTarget->enmPlaneFormat == DXGI_FORMAT_R8_UNORM
                 || pHwOutputTarget->enmPlaneFormat == DXGI_FORMAT_R16_UNORM,
                 VERR_NOT_SUPPORTED);

    uint32_t const cWidthY  = pOutputTarget->desc.cWidth;
    uint32_t const cHeightY = pOutputTarget->desc.cHeight;
    uint32_t const cWidthUV  = cWidthY  / 2;
    uint32_t const cHeightUV = cHeightY / 2;

    size_t const cbY = (size_t)cWidthY * cHeightY;
    size_t const cbUV = (size_t)cWidthUV * cHeightUV;

    uint8_t *pu8DstY = (uint8_t *)pOutputTarget->desc.pvOutputBuffer;
    uint8_t *pu8DstU = pu8DstY + cbY;
    uint8_t *pu8DstV = pu8DstU + cbUV;

    int rc = vmsvgaHwOutputTargetCopyPlane(pDeviceContext, pHwOutputTarget->y.pT2DStaging,
                                           cWidthY, cHeightY, pHwOutputTarget->enmPlaneFormat, pu8DstY);
    if (RT_SUCCESS(rc))
        rc = vmsvgaHwOutputTargetCopyPlane(pDeviceContext, pHwOutputTarget->u.pT2DStaging,
                                           cWidthUV, cHeightUV, pHwOutputTarget->enmPlaneFormat, pu8DstU);
    if (RT_SUCCESS(rc))
        rc = vmsvgaHwOutputTargetCopyPlane(pDeviceContext, pHwOutputTarget->v.pT2DStaging,
                                           cWidthUV, cHeightUV, pHwOutputTarget->enmPlaneFormat, pu8DstV);
    return rc;
}
