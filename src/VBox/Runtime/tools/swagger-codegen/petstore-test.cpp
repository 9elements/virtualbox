/* $Id: petstore-test.cpp 114031 2026-04-27 08:07:08Z knut.osmundsen@oracle.com $ */
/** @file
 * Handwritten swagger pet shop sample.
 */

/*
 * Copyright (C) 2018-2026 Oracle and/or its affiliates.
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
 * The contents of this file may alternatively be used under the terms
 * of the Common Development and Distribution License Version 1.0
 * (CDDL), a copy of it is provided in the "COPYING.CDDL" file included
 * in the VirtualBox distribution, in which case the provisions of the
 * CDDL are applicable instead of those of the GPL.
 *
 * You may elect to license modified versions of this file under the
 * terms and conditions of either the GPL or the CDDL or both.
 *
 * SPDX-License-Identifier: GPL-3.0-only OR CDDL-1.0
 */


/*********************************************************************************************************************************
*   Header Files                                                                                                                 *
*********************************************************************************************************************************/
#include <iprt/initterm.h>
#include <iprt/message.h>
#include <iprt/stream.h>
#include <iprt/cpp/restoutput.h>

#include "api/PetApi.h"
#include "api/StoreApi.h"
#include "api/UserApi.h"



petstore::PetApi *getApi()
{
    petstore::PetApi *pApi = new petstore::PetApi();
    pApi->setServerAuthority("petstore.swagger.io");
    return pApi;
}



int main()
{
    int rc = RTR3InitExeNoArguments(0);
    if (RT_FAILURE(rc))
        return RTMsgInitFailure(rc);

    /*
     * Good debug environment setup to best see what's going on:
     *
     *    VBOX_LOG=rt_http=~0 rt_rest=~0
     *    VBOX_LOG_DEST=nofile stderr
     *    VBOX_LOG_FLAGS=unbuffered enabled thread msprog
     *
     */

    /* Find pets by status: */
    int64_t idPet = 1;
    {
        petstore::PetApi *pApi = getApi();

        petstore::FindPetsByStatusRequest Request;
        Request.appendToStatus(petstore::FindPetsByStatusRequest::kStatusEnum_Available);
        Request.appendToStatus(petstore::FindPetsByStatusRequest::kStatusEnum_Pending);
        //Request.appendToStatus(petstore::FindPetsByStatusRequest::kStatusEnum_Sold);
        petstore::FindPetsByStatusResponse Response;
        rc = pApi->findPetsByStatus(&Response, Request);
        RTPrintf("Reponse #1: rc=%Rrc http=%Rrc content-type=%s\n",
                 rc, Response.getHttpStatus(), Response.getContentType().c_str());
        if (Response.getErrInfo())
            RTPrintf("        error info: %Rrc: %s\n", Response.getErrInfo()->rc, Response.getErrInfo()->pszMsg);
        if (Response.hasPetList())
        {
            RTCRestArray< petstore::Pet > const *pPets = Response.getPetList();
            RTPrintf("  Got %zu pets\n", pPets->size());
            for (size_t i = 0; i < pPets->size(); i++)
            {
                petstore::Pet const *pPet = pPets->at(i);
                if (pPet->isNull())
                    RTPrintf("  #%u: <null>\n", i);
                else
                {
                    RTPrintf("  #%u: %s\n", i, pPet->getName().c_str());
                    if (i < 64)
                        idPet = pPet->getId();
                }
            }
        }

        delete pApi;
    }

    /* Use the pet ID we found above to get a pet by ID: */
    {
        petstore::PetApi *pApi = getApi();

        petstore::GetPetByIdRequest Request;
        Request.setPetId(idPet);
        petstore::GetPetByIdResponse Response;
        rc = pApi->getPetById(&Response, Request);
        RTPrintf("Reponse #2: rc=%Rrc http=%Rrc content-type=%s\n",
                 rc, Response.getHttpStatus(), Response.getContentType().c_str());
        if (Response.getErrInfo())
            RTPrintf("        error info: %Rrc: %s\n", Response.getErrInfo()->rc, Response.getErrInfo()->pszMsg);
        petstore::Pet const *pPet = Response.getPet();
        if (pPet)
        {
            if (pPet->isNull())
                RTPrintf("       pet#%RI64: <null>\n", idPet);
            else
                RTPrintf("       pet#%RI64: %s\n", idPet, pPet->getName().c_str());

            RTCString strJson;
            RTCRestOutputToString Out(&strJson);
            pPet->serializeAsJson(Out);
            Out.finalize();
            RTPrintf("condense json: %s\n", strJson.c_str());

            RTCRestOutputPrettyToString Pretty(&strJson);
            pPet->serializeAsJson(Pretty);
            Pretty.finalize();
            RTPrintf("pretty json:\n%s\n", strJson.c_str());
        }

        delete pApi;
    }

    /* Use updatePetWithForm to do a no-change modification to the pet: */
    {
        petstore::PetApi *pApi = getApi();

        petstore::UpdatePetWithFormResponse Response;
        rc = pApi->updatePetWithForm(&Response, idPet);
        RTPrintf("Reponse #3: rc=%Rrc http=%Rrc content-type=%s\n",
                 rc, Response.getHttpStatus(), Response.getContentType().c_str());
        if (Response.getErrInfo())
            RTPrintf("        error info: %Rrc: %s\n", Response.getErrInfo()->rc, Response.getErrInfo()->pszMsg);

        delete pApi;
    }


    //getPetById

#if 0
    /* Create, update and kill a pet: */
    {
        petstore::FindPetsByStatusRequest Request;
        Request.appendToStatus("available");
        Request.appendToStatus("pending");
        Request.appendToStatus("sold");
        petstore::FindPetsByStatusResponse Response;
        int rc = pApi->findPetsByStatus(&Response, Request);
        RTPrintf("Reponse #1: rc=%Rrc http=%Rrc content-type=%s\n",
                 rc, Response.getHttpStatus(), Response.getContentType().c_str());
        if (Response.getErrInfo())
            RTPrintf("        error info: %Rrc: %s\n", Response.getErrInfo()->rc, Response.getErrInfo()->pszMsg);
        if (Response.hasPetList())
        {
            RTCRestArray< petstore::Pet > const *pPets = Response.getPetList();
            RTPrintf("  Got %zu pets\n", pPets->size());
            for (size_t i = 0; i < pPets->size(); i++)
            {
                petstore::Pet const *pPet = pPets->at(i);
                RTPrintf("  #%u: %s\n", i, pPet->getName().c_str());
            }
        }

    }
#endif

    return RTEXITCODE_SUCCESS;
}
