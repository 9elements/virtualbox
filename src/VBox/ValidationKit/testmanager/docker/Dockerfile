# $Id: Dockerfile 114016 2026-04-24 13:18:04Z andreas.loeffler@oracle.com $
## @file
# VirtualBox Validation Kit - Dockerfile for running a local Testmanager instance
#                             inside a Docker container.

#
#
# Copyright (C) 2019-2026 Oracle and/or its affiliates.
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

# Important: Always keep the actual container independent from the data which
#            is being used, so that it can be rebuilt / restarted at any time.
#            Read Docker's best practises for more information.

#
# Ways to use:
# 1. Preferred way: Execute "kmk build", "kmk start" and "kmk stop" to build,
#    start and stop the environment respectively.
# 2. Use an own script to e.g. use bind mounts instead of a dedicated data volume.
#    This can be handy if you want to share the Test Manager source with your host
#    for having a fast(er) development cycle.
# 3. Use an own docker-compose .yaml file to match your needs.
#

# Docker setup:
#   - Install docker-ce and docker-compose
#   - sudo usermod -aG docker ${USER}    (may needs a restart)

## @todo Reduce layers to make container building faster.

FROM alpine

# Proxy fun.
ARG http_proxy
ARG https_proxy

# Install packages.
RUN apk update && apk upgrade && \
    apk add --no-cache apache2 apache2-utils bash ca-certificates g++ openrc \
                       postgresql-client postgresql-dev \
                       subversion nasm yasm

# PHP stuff, needed for Adminer.
RUN apk add --no-cache php83-apache2 php83-fpm php83-session php83-pgsql php83-pdo_pgsql

# Python stuff, needed for the Test Manager.
RUN apk add --no-cache python3-dev py3-pip py3-pylint py3-psycopg2

# Add required Test Manager files.
ADD testmgr-env.sh testmgr-init.sh testmgr-update.sh /

# Cleanup.
RUN rm -rf /var/cache/apk/* && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /var/www/localhost/htdocs/*

# Expose Apache.
EXPOSE 80

ENTRYPOINT ["/testmgr-init.sh"]
