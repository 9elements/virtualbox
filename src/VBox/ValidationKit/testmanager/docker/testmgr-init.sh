#!/bin/sh

# $Id: testmgr-init.sh 114023 2026-04-24 15:20:58Z andreas.loeffler@oracle.com $
## @file
# VirtualBox Validation Kit - Init script for the Testmanager running
#                             inside a Docker container.
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

source /testmgr-env.sh

# Enable this to get some more debugging output.
MY_DEBUG=

if [ -n "$MY_DEBUG" ]; then
    set -x
    env
    ping -c 3 ${PSQL_DB_HOST}
    echo "VBox root is $MY_VBOX_ROOT:"
    ls ${MY_VBOX_ROOT}
    echo "Using database: $PSQL_DB_HOST:$PSQL_DB_PORT"
fi

# If no VBox installation is found, check it out from SVN.
if [ ! -d "$MY_VBOX_ROOT/src" ]; then

    echo "Checking out VBox + Test Manager ..."

    # If no repo is specified, use public OSE repos instead.
    if [ -z "$VBOX_REPO_URL" ]; then
        VBOX_REPO_URL=http://www.virtualbox.org/svn/vbox/trunk
    fi

    MY_SVN_OPTS=--trust-server-cert

    # Checkout prerequisites.
    svn co ${MY_SVN_OPTS} ${VBOX_REPO_URL} --depth=files ${MY_VBOX_ROOT}

    # Checkout common Python modules, required also for the Testmanager.
    mkdir -p ${MY_VBOX_VALKIT_ROOT}/common
    svn co ${MY_SVN_OPTS} ${VBOX_REPO_URL}/src/VBox/ValidationKit/common ${MY_VBOX_VALKIT_ROOT}/common

    # Checkout Testmanager stuff.
    mkdir -p ${MY_VBOX_TESTMGR_ROOT}
    svn co ${MY_SVN_OPTS} ${VBOX_REPO_URL}/src/VBox/ValidationKit/testmanager ${MY_VBOX_TESTMGR_ROOT}

    # Checkout & update kBuild.
    if [ -z "$KBUILD_REPO_URL" ]; then
        KBUILD_REPO_URL=http://www.virtualbox.org/svn/kbuild-mirror/trunk
    fi
    # Only checkout stuff we really need.
    svn co ${MY_SVN_OPTS} ${KBUILD_REPO_URL}/kBuild ${MY_VBOX_ROOT}/kBuild --depth immediates
    cd ${MY_VBOX_ROOT}/kBuild/ && svn update --set-depth immediates
    cd ${MY_VBOX_ROOT}/kBuild/tools/ && svn update --set-depth infinity
    cd ${MY_VBOX_ROOT}/kBuild/bin/ && svn update --set-depth immediates
    cd ${MY_VBOX_ROOT}/kBuild/bin/${MY_VBOX_BUILD_SPEC}/ && svn update --set-depth infinity

fi

MY_APACHE_CONFIG=/etc/apache2/httpd.conf

# Enable CGI.
sed -i -e '/index\.html$/s/$/ index.sh index.cgi/' \
       -e '/LoadModule cgi/s/#//' \
       -e '/Scriptsock cgisock/s/#//' \
       -e '/AddHandler cgi-script .cgi/s/#//' \
       -e '/AddHandler cgi-script .cgi/s/$/ .sh .py/' \
       -e '/Options Indexes FollowSymLinks/s/$/ ExecCGI/' ${MY_APACHE_CONFIG}

MY_PGPASS_FILE=~/.pgpass
echo "$POSTGRES_HOST:$POSTGRES_PORT:testmanager:$POSTGRES_USER:$POSTGRES_PASSWORD" > ${MY_PGPASS_FILE}
chmod 600 ${MY_PGPASS_FILE}
export PGPASSWORD=${POSTGRES_PASSWORD}

cat <<EOF >>${MY_APACHE_CONFIG}
Define ServerName "Docker - VBox Test Manager"
Define TestManagerRootDir "$MY_VBOX_TESTMGR_ROOT"
Define VBoxBuildOutputDir "/tmp"
Include "$MY_VBOX_TESTMGR_ROOT/apache-template-2.4.conf"
EOF

# HACK ALERT: Install glibc manually. Alpine uses musl, which in turn does not
#             provide all APIs we need for kmk.
apk --no-cache add ca-certificates wget &&
wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub &&
wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.28-r0/glibc-2.28-r0.apk &&
apk --no-cache add glibc-2.28-r0.apk &&
rm glibc-2.28-r0.apk

cd ${MY_VBOX_TESTMGR_ROOT}/db
kmk load-testmanager-db

# The CGI interface uses "python" as command, so just link to Python 3.
ln -s /usr/bin/python3 /usr/bin/python

# HACK ALERT: Patch the Test Manager's config to be able to connect to the remote Postgres server.
MY_TESTMGR_CFG=${MY_VBOX_TESTMGR_ROOT}/config.py
sed -i "s/g_ksDatabaseAddress.*=.*None.*/g_ksDatabaseAddress = \"$POSTGRES_HOST\"/g" ${MY_TESTMGR_CFG}
sed -i "s/g_ksDatabasePassword.*=.*''.*/g_ksDatabasePassword = \"$POSTGRES_PASSWORD\"/g" ${MY_TESTMGR_CFG}

# Install Adminer as a frontend to the database and remove empty default page.
MY_ADMINER_VER=4.8.1
MY_HTDOCS_DIR=/var/www/localhost/htdocs
wget q -O ${MY_HTDOCS_DIR}/index.php https://github.com/vrana/adminer/releases/download/v${MY_ADMINER_VER}/adminer-${MY_ADMINER_VER}-en.php

httpd -DFOREGROUND
