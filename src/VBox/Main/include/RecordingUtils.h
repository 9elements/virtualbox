/* $Id: RecordingUtils.h 113625 2026-03-27 13:46:36Z andreas.loeffler@oracle.com $ */
/** @file
 * Recording utility header.
 */

/*
 * Copyright (C) 2012-2026 Oracle and/or its affiliates.
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

#ifndef MAIN_INCLUDED_RecordingUtils_h
#define MAIN_INCLUDED_RecordingUtils_h
#ifndef RT_WITHOUT_PRAGMA_ONCE
# pragma once
#endif

#ifndef IN_VBOXSVC /* Code only used in VBoxC. */
#include "RecordingInternals.h"
#include "RecordingRender.h"

const char *RecordingUtilsFrameTypeToStr(RECORDINGFRAME_TYPE enmType);
const char *RecordingUtilsRenderBackendToStr(RECORDINGRENDERBACKEND enmBackend);
#endif

const char *RecordingUtilsAudioCodecToStr(RecordingAudioCodec_T enmCodec);
const char *RecordingUtilsVideoCodecToStr(RecordingVideoCodec_T enmCodec);
const char *RecordingUtilsVideoScalingModeToStr(RecordingVideoScalingMode_T enmMode);

size_t RecordingUtilsCalcCapacityFromLatency(RTMSINTERVAL msLatencyBudget, size_t msPerFrame, size_t cMin, size_t cMax);
size_t RecordingUtilsCalcCapacityFromFpsAndLatency(size_t uFPS, RTMSINTERVAL msLatencyBudget, size_t uMinFPS, size_t uMaxFPS);

#ifndef IN_VBOXSVC /* Code only used in VBoxC. */

#ifdef DEBUG
int RecordingDbgDumpImageData(const uint8_t *pu8RGBBuf, size_t cbRGBBuf, const char *pszPath, const char *pszWhat, uint32_t uX, uint32_t uY, uint32_t uWidth, uint32_t uHeight, uint32_t uBytesPerLine, uint8_t uBPP, uint64_t msTimestamp = UINT64_MAX);
int RecordingDbgDumpVideoFrameEx(const PRECORDINGVIDEOFRAME pFrame, const char *pszPath, const char *pszWhat, uint64_t msTimestamp);
int RecordingDbgDumpVideoFrame(const PRECORDINGVIDEOFRAME pFrame, const char *pszWhat, uint64_t msTimestamp);
void RecordingDbgLogFrame(PRECORDINGFRAME pFrame);
void RecordingDbgAddVideoFrameBorder(PRECORDINGVIDEOFRAME pFrame);
#endif
#endif

#endif /* !MAIN_INCLUDED_RecordingUtils_h */

