#!/bin/sh

# $Id: testmgr-env.sh 114016 2026-04-24 13:18:04Z andreas.loeffler@oracle.com $
## @file
# VirtualBox Validation Kit - Environment setup script for the Testmanager running
#                             inside a Docker container.
#

#
#
# Copyright (C) 2020-2026 Oracle and/or its affiliates.
#
# This file is part of VirtualBox base platform packages, as
# available from https://www.virtualbox.org.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation, in version 3 of the
# License.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, see <https://www.gnu.org/licenses>.
#
# The contents of this file may alternatively be used under the terms
# of the Common Development and Distribution License Version 1.0
# (CDDL), a copy of it is provided in the "COPYING.CDDL" file included
# in the VirtualBox distribution, in which case the provisions of the
# CDDL are applicable instead of those of the GPL.
#
# You may elect to license modified versions of this file under the
# terms and conditions of either the GPL or the CDDL or both.
#
# SPDX-License-Identifier: GPL-3.0-only OR CDDL-1.0
#

MY_VBOX_ROOT=/vbox
MY_VBOX_VALKIT_ROOT=${MY_VBOX_ROOT}/src/VBox/ValidationKit
MY_VBOX_TESTMGR_ROOT=${MY_VBOX_VALKIT_ROOT}/testmanager

MY_VBOX_BUILD_SPEC=linux.amd64 ## @todo Make this more flexible.

export ENV LANG=en_US.utf8

export MY_VBOX_ROOT
export MY_VBOX_VALKIT_ROOT
export MY_VBOX_TESTMGR_ROOT

export USERNAME=vbox-testmgr-dev
export PATH_KBUILD_BIN=${MY_VBOX_ROOT}/kBuild/bin/${MY_VBOX_BUILD_SPEC}
export PATH_DEVTOOLS=${MY_VBOX_ROOT}/tools
export PATH=${PATH_KBUILD_BIN}:${PATH}

# Connection to Postgres server container.
export POSTGRES_HOST=vbox-testmgr-db

# Needed for Makefile.
export PSQL_DB_HOST=${POSTGRES_HOST}
export PSQL_DB_PORT=${POSTGRES_PORT}
export PSQL_DB_USER=${POSTGRES_USER}
export PSQL_DB_PASSWORD=password
