#!/usr/bin/env kmk_ash
# $Id: dita-ot-bld.sh 113977 2026-04-22 20:32:22Z knut.osmundsen@oracle.com $
## @file
# Shell script to build dita-ot and the necessary dependencies.
# See bugref:10402.
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
# SPDX-License-Identifier: GPL-3.0-only
#

set -x -e

#
# Check environment.
#
test -n "${MY_BLD_DIR}"
test -d "${MY_BLD_DIR}"
test -n "${MY_MAVEN_DIR}"
test -n "${MY_GRADLE_DIR}"
test -n "${JAVA_HOME}"
test -n "${GRADLE_USER_HOME}"
test -n "${MAVEN_HOME}"

7z --help > /dev/null
unzip --help > /dev/null
svn --help > /dev/null
patch -v > /dev/null
#diff -v > /dev/null

#
# Parameters
#
MY_PROXY=
if test "$1" != "--no-proxy"; then MY_PROXY=1; fi


#
# Variables.
#
       MY_GRADLE_USER_HOME=${GRADLE_USER_HOME}
MY_GRADLE_VIRGIN_USER_HOME=${GRADLE_USER_HOME}-virgin
                MY_BLD_DIR=$(echo "${MY_BLD_DIR}" | kmk_sed -e 's/\\/\//g' -e 's/[/]*$//')
    MY_BLD_DIR_DOS_SLASHES=$(echo "${MY_BLD_DIR}" | kmk_sed -e 's/\//\\/g')
           MY_DOWNLOAD_DIR="${MY_BLD_DIR}/downloads"
         MY_MAVEN_REPO_DIR="${MY_BLD_DIR}/repo-maven"          # staging
   MY_MAVEN_LOCAL_REPO_DIR="${MY_BLD_DIR}/repo-maven-local"    # caching
  MY_MAVEN_VIRGIN_REPO_DIR="${MY_BLD_DIR}/repo-maven-virgin"   # caching (local repo)
          MY_FLAT_REPO_DIR="${MY_BLD_DIR}/repo-flat"

#MY_JVM_PROXY_OPTS=" \
#-Dhttp.proxyHost=www-proxy-ams.nl.oracle.com \
#-Dhttp.proxyPort=80 \
#-Dhttps.proxyHost=www-proxy-ams.nl.oracle.com \
#-Dhttps.proxyPort=80 \
#"
MY_JVM_PROXY_OPTS="-Djava.net.useSystemProxies=1"

MY_SVN_PROXY_OPTS=""
if test -n "${MY_PROXY}"; then
    MY_SVN_PROXY_OPTS="${MY_SVN_PROXY_OPTS} \
--config-option servers:global:http-proxy-port=80 \
--config-option servers:global:http-proxy-host=www-proxy-ams.nl.oracle.com \
"
fi


#
# Helper functions.
#

# Downloads a file to the download directory.
# 1=hash 2=filename 3=baseurl [4=tailurl]
download()
{
    if test -f "${MY_DOWNLOAD_DIR}/${2}" && kmk_md5sum -b -C "${1}" "${MY_DOWNLOAD_DIR}/${2}"; then
        echo "info: ${MY_DOWNLOAD_DIR}/${2} already downloaded"
    else
        echo "info: Downloading ${MY_DOWNLOAD_DIR}/${2} ..."
        if test -z "${4}"; then
            RTHttp -o "${MY_DOWNLOAD_DIR}/${2}" "${3}/${2}"
        else
            RTHttp -o "${MY_DOWNLOAD_DIR}/${2}" "${3}/${4}"
        fi
        if test -n "${1}"; then
            kmk_md5sum -b -C "${1}" "${MY_DOWNLOAD_DIR}/${2}"
        fi
    fi
}

unpack_in_bld_root()
{
    echo "info: Unpacking $1..."
    cd "${MY_BLD_DIR}"
    7z x "${1}"
}

unpack_in_dir()
{
    echo "info: Unpacking $1 in $2..."
    kmk_mkdir -p -- "${MY_BLD_DIR}/$2"
    cd "${MY_BLD_DIR}/$2"
    7z x "${1}"
}


# Downloads a file to the download directory and unpacks it in the build directory root.
# 1=filename 2=baseurl [3=tailurl]
download_and_unpack_in_bld_root()
{
    download "$1" "$2" "$3" "$4"
    unpack_in_bld_root "${MY_DOWNLOAD_DIR}/${2}"
}

# Runs the default version of maven.
run_mvn()
{
    echo "info: Running: cmd /c mvm.cmd $* ..."
    cmd /c mvn.cmd $*
}

# Runs the default version of gradle.
run_gradle()
{
    echo "info: Running: cmd /c gradle.bat $* ..."
    cmd /c gradle.bat $*
}

# Runs the version of ant that we built.
run_ant()
{
    echo "info: Running: cmd /c ant.bat $* ..."
    cmd /c "${MY_BLD_DIR_DOS_SLASHES}\\apache-ant-1.10.12-tool\\apache-ant-1.10.12\\bin\\ant.bat" $*
}


#
# Steps.
#

# Create the directory layout under the build directory.
create_layout()
{
    kmk_mkdir -p -- \
        "${MY_DOWNLOAD_DIR}" \
        "${MY_MAVEN_REPO_DIR}" \
        "${MY_MAVEN_VIRGIN_REPO_DIR}" \
        "${MY_MAVEN_LOCAL_REPO_DIR}" \
        "${MY_FLAT_REPO_DIR}"
}

# Get the latest gradle binary distor, which is 8.1.1.
get_and_install_gradle()
{
    download_and_unpack_in_bld_root "b58a59d5635f69822b8670a80c9d166a" "gradle-8.1.1-bin.zip" "https://services.gradle.org/distributions/"
}

# Configures gradle.
configure_gradle()
{
    test -n "${MY_GRADLE_USER_HOME}"
    if test "$1" = "virgin"; then
        export GRADLE_USER_HOME=${MY_GRADLE_VIRGIN_USER_HOME}
    else
        export GRADLE_USER_HOME=${MY_GRADLE_USER_HOME}
    fi

    kmk_mkdir -p -- "${GRADLE_USER_HOME}"
    if test "$1" = "virgin"; then
        kmk_echo "maven.repo.local=${MY_MAVEN_LOCAL_REPO_DIR}"  > "${GRADLE_USER_HOME}/gradle.properties" # TODO: echo makes it kmk_ash stop.
    else
        kmk_echo "maven.repo.local=${MY_MAVEN_VIRGIN_REPO_DIR}" > "${GRADLE_USER_HOME}/gradle.properties"
    fi

    if test -z "${MY_PROXY}"; then
        kmk_cat >> "${GRADLE_USER_HOME}/gradle.properties" <<EOF
systemProp.java.net.useSystemProxies=true
systemProp.https.proxyHost=www-proxy-ams.nl.oracle.com
systemProp.https.proxyPort=80
systemProp.http.nonProxyHosts=*.oraclecorp.com|*.de.oracle.com|localhost
EOF
    fi
}

# Get the latest apache maven binary distor, which is 3.9.1.
get_and_install_maven()
{
    download_and_unpack_in_bld_root "53733365d9714c47be94d206c6346aa6" "apache-maven-3.9.1-bin.zip" "https://dlcdn.apache.org/maven/maven-3/3.9.1/binaries/"
}

# Configures maven.  This modifies the maven install.
# ASSUMES the default settings.xml is bascially empty.
configure_maven()
{
    kmk_mkdir -p -- "${MAVEN_HOME}/conf"
    if ! test -f "${MAVEN_HOME}/conf/settings-org.xml"; then
        kmk_mv -v -- "${MAVEN_HOME}/conf/settings.xml" "${MAVEN_HOME}/conf/settings-org.xml"
    fi
    kmk_cat > "${MAVEN_HOME}/conf/settings.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.2.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.2.0 https://maven.apache.org/xsd/settings-1.2.0.xsd">
EOF
    if test "$1" = "virgin"; then
        kmk_echo "  <localRepository>${MY_MAVEN_VIRGIN_REPO_DIR}</localRepository>" >> "${MAVEN_HOME}/conf/settings.xml"
    else
        kmk_echo "  <localRepository>${MY_MAVEN_LOCAL_REPO_DIR}</localRepository>" >> "${MAVEN_HOME}/conf/settings.xml"
    fi
    kmk_cat >> "${MAVEN_HOME}/conf/settings.xml" <<EOF
  <!-- interactiveMode>true</interactiveMode -->
  <!-- offline>false</offline -->

  <pluginGroups/>

  <proxies>
EOF
    if test -n "${MY_PROXY}"; then
        kmk_cat >> "${MAVEN_HOME}/conf/settings.xml" <<EOF
    <proxy>
      <id>oracle .nl - http</id>
      <active>true</active>
      <protocol>http</protocol>
      <host>www-proxy-ams.nl.oracle.com</host>
      <port>80</port>
      <nonProxyHosts>*.oraclecorp.com|*.de.oracle.com|localhost</nonProxyHosts>
    </proxy>
    <proxy>
      <id>oracle .nl - https</id>
      <active>true</active>
      <protocol>https</protocol>
      <host>www-proxy-ams.nl.oracle.com</host>
      <port>80</port>
      <nonProxyHosts>*.oraclecorp.com|*.de.oracle.com|localhost</nonProxyHosts>
    </proxy>
EOF
    fi
    kmk_cat >> "${MAVEN_HOME}/conf/settings.xml" <<EOF
  </proxies>

  <servers/>
  <mirrors>
    <mirror>
      <id>maven-default-http-blocker</id>
      <mirrorOf>external:http:*</mirrorOf>
      <name>Pseudo repository to mirror external repositories initially using HTTP.</name>
      <url>http://0.0.0.0/</url>
      <blocked>true</blocked>
    </mirror>
  </mirrors>

  <profiles/>

  <activeProfiles/>
</settings>
EOF
}

# Get, set up and build the desired apache ant version.
#
# Parameter $1 is either 'tool' or 'final'. We first build a version that we
# use to build a couple of the other dependencies, but this won't include all
# we need to run dita-ot because ant and it both needs xml-resolver-1.2.jar
# (and possibly other stuff).  So, we're doing a second build later on with
# $1='final' which we'll copy to the repository for use.
#
# Note! Disabling javadoc as java 17 is just too strict.
# Note! Do _not_ set java-repository.dir to point at MY_MAVEN_REPO_DIR, it will be deleted.
# Note! This is just for building, we'll have to rebuild ant again for
#       use with dita-ot when we've produced xml-resolver-1.2.jar and other
#       stuff needed.
get_and_setup_and_build_ant()
{
    download_and_unpack_in_bld_root "61011f1ba55f5a2056fca8db7f02b179" "apache-ant-1.10.12-src.zip" "https://dlcdn.apache.org//ant/source/"
    kmk_mv -v -- "${MY_BLD_DIR}/apache-ant-1.10.12/" "${MY_BLD_DIR}/apache-ant-1.10.12-$1/"
    cd "${MY_BLD_DIR}/apache-ant-1.10.12-$1/"

    if ! test -f build.xml-org; then kmk_mv -v -- build.xml build.xml-org; fi
    kmk_sed -e '/<xz /,/\/>/{d}' --output build.xml build.xml-org

    kmk_mkdir -p -- build/javadocs # crude hack to counter build.xml:1398 failure

    if test "$1" = "tool"; then
        cmd /c build.bat -v -v -v -v -v -d -Djavadoc.notrequired=1 main-distribution

    elif test "$1" = "final"; then
        MY_SAVED_CLASSPATH=${CLASSPATH}
        CLASSPATH="${MY_MAVEN_REPO_DIR}/xml-resolver/xml-resolver/1.2/xml-resolver-1.2.jar"                # Needed
        CLASSPATH="${CLASSPATH};${MY_MAVEN_REPO_DIR}/xml-apis/xml-apis/1.4.01/xml-apis-1.4.01.jar"         # Just in case...
        CLASSPATH="${CLASSPATH};${MY_MAVEN_REPO_DIR}/xml-apis/xml-apis-ext/1.4.01/xml-apis-ext-1.4.01.jar" # Just in case...
        CLASSPATH="${CLASSPATH};${MY_MAVEN_REPO_DIR}/commons-io/commons-io/2.8.0/commons-io-2.8.0.jar"     # Just in case...
        CLASSPATH="${CLASSPATH};${MY_BLD_DIR}/jing-trang-20181222/lib/xalan.jar"                           # Whatever.
        export CLASSPATH="${CLASSPATH};${MY_SAVED_CLASSPATH}"

        run_ant -v -v -v -v -v -d -Djavadoc.notrequired=1 -Dbuild.sysclasspath=last main-distribution
        kmk_cp -Rv java-repository/* "${MY_MAVEN_REPO_DIR}/"

        CLASSPATH=${MY_SAVED_CLASSPATH}
    else
        echo "error: Invalid parameter: $1"
        exit 1
    fi
}

# Get, set up and build the desired FastXML jackson-bom (dummy, but whatever).
# Note! Dropping some org.sonatype.plugins stuff.
get_and_setup_and_build_jackson_bom()
{
    download_and_unpack_in_bld_root "d73f9ccb3d40604535ed146cb024a018" "jackson-bom-2.13.4.zip" "https://codeload.github.com/FasterXML/jackson-bom/zip/refs/tags/" "jackson-bom-2.13.4"
    cd "${MY_BLD_DIR}/jackson-bom-jackson-bom-2.13.4/"
    kmk_mv -v -- pom.xml pom.xml-org
    kmk_sed -e '/<repositories>/,/<\/repositories>/{d}' --output pom.xml pom.xml-org
    kmk_mv -f base/pom.xml base/pom.xml-org
    kmk_sed -e '/12-Oct-2019, tatu: Copied from/,/<\/plugin>/{d}' --output base/pom.xml base/pom.xml-org
    run_mvn deploy "-DaltDeploymentRepository=release-repo::file:///${MY_MAVEN_REPO_DIR}"
}

# Get, set up and build the desired FastXML jackson-core.
# Note! Changing JDK version from 1.6 to 17 to make it build.
get_and_setup_and_build_jackson_core()
{
    download_and_unpack_in_bld_root "e283de98759a24244c8af65975b82a7f" "jackson-core-2.13.4.zip" "https://codeload.github.com/FasterXML/jackson-core/zip/refs/tags/" "jackson-core-2.13.4"
    cd "${MY_BLD_DIR}/jackson-core-jackson-core-2.13.4/"
    kmk_mv -v -- pom.xml pom.xml-org
    kmk_sed -e 's/>1.6</>17</g' --output pom.xml pom.xml-org
    run_mvn deploy "-DaltDeploymentRepository=release-repo::file:///${MY_MAVEN_REPO_DIR}"
}

# Get, set up and build the desired FastXML jackson-dataformats-text.
# Note! Changing JDK version from 1.6 to 17 to make it build.
get_and_setup_and_build_jackson_dataformats_text()
{
    download_and_unpack_in_bld_root "d52554a198de967c1c8c478d34142253" "jackson-dataformats-text-2.13.4.zip" "https://github.com/FasterXML/jackson-dataformats-text/archive/refs/tags/"
    cd "${MY_BLD_DIR}/jackson-dataformats-text-jackson-dataformats-text-2.13.4/"
    kmk_mv -v -- pom.xml pom.xml-org
    kmk_sed -e '/<module>toml<\/module>/d' --output pom.xml pom.xml-org
    run_mvn deploy "-DaltDeploymentRepository=release-repo::file:///${MY_MAVEN_REPO_DIR}"
}

# Get, set up and build the xml-commons-resolver-1.2.zip
# The oscs-oci-oracledist version of this has an incorrect junit+hamcrest
# dependency because they included the testcase.  They skipped the etc
# directory, though, so it's incomplete. Sigh.
#
# No build script here, only some ancient drafty ant stuff, so do it manually.
#
## @todo could check this out from svn like get_and_setup_and_build_xml_external and get something buildable using ant.
get_and_setup_and_build_xml_resolver()
{
    download_and_unpack_in_bld_root "e1016770401dc0a8207f9358878e3c84" "xml-commons-resolver-1.2.zip" "https://archive.apache.org/dist/xml/commons/"
    cd "${MY_BLD_DIR}/xml-commons-resolver-1.2/"
    "${JAVA_HOME}/bin/javac" -Xlint:none -d build \
        src/org/apache/xml/resolver/*java \
        src/org/apache/xml/resolver/apps/*java \
        src/org/apache/xml/resolver/helpers/*java \
        src/org/apache/xml/resolver/readers/*java \
        src/org/apache/xml/resolver/tools/*java
    kmk_cp -Rv -- etc build/org/apache/xml/resolver/etc
    cd build
    "${JAVA_HOME}/bin/jar" cvf xml-resolver-1.2.jar *
    "${JAVA_HOME}/bin/jar" -i xml-resolver-1.2.jar
    kmk_mkdir -p -- "${MY_MAVEN_REPO_DIR}/xml-resolver/xml-resolver/1.2/"

    kmk_cp -v -- xml-resolver-1.2.jar "${MY_MAVEN_REPO_DIR}/xml-resolver/xml-resolver/1.2/xml-resolver-1.2.jar"
    kmk_cat                         > "${MY_MAVEN_REPO_DIR}/xml-resolver/xml-resolver/1.2/xml-resolver-1.2.pom" <<EOF
<?xml version="1.0" encoding="UTF-8"?><project>
  <parent>
    <artifactId>apache</artifactId>
    <groupId>org.apache</groupId>
    <version>3</version>
  </parent>
  <modelVersion>4.0.0</modelVersion>
  <groupId>xml-resolver</groupId>
  <artifactId>xml-resolver</artifactId>
  <name>XML Commons Resolver Component</name>
  <version>1.2</version>
  <description>xml-commons provides an Apache-hosted set of DOM, SAX, and
    JAXP interfaces for use in other xml-based projects. Our hope is that we
    can standardize on both a common version and packaging scheme for these
    critical XML standards interfaces to make the lives of both our developers
    and users easier.</description>
  <url>http://xml.apache.org/commons/components/resolver/</url>
  <issueManagement>
    <system>bugzilla</system>
    <url>http://issues.apache.org/bugzilla/</url>
  </issueManagement>
  <mailingLists>
    <mailingList>
      <name>XML Commons Developer's List</name>
      <subscribe>commons-dev-subscribe@xml.apache.org</subscribe>
      <unsubscribe>commons-dev-unsubscribe@xml.apache.org</unsubscribe>
      <post>commons-dev@xml.apache.org</post>
      <archive>http://mail-archives.apache.org/mod_mbox/xml-commons-dev/</archive>
    </mailingList>
  </mailingLists>
  <scm>
    <connection>scm:svn:https://svn.apache.org/repos/asf/xerces/xml-commons/tags/xml-commons-resolver-1_2/</connection>
    <url>https://svn.apache.org/viewvc/xerces/xml-commons/tags/xml-commons-resolver-1_2/</url>
  </scm>
  <dependencies/>
</project>
EOF
}

# Use svn to get this stuff, as the repo include build.xml files which the
# https://archive.apache.org/dist/xml/commons/xml-commons-external-1.4.01-src.zip
# archive (zip-bomb) does not.
#
# The oscs-oci-oracledist version of this was just copied from maven-central it
# seems, with modified POM files (used here) that includes some PLS approval stuff.
get_and_setup_and_build_xml_external()
{
    cd "${MY_BLD_DIR}"
    svn ${MY_SVN_PROXY_OPTS} export https://svn.apache.org/repos/asf/xerces/xml-commons/tags/xml-commons-external-1_4_01/ xml-commons-external-1_4_01
    cd "${MY_BLD_DIR}/xml-commons-external-1_4_01/java/external"

    if ! test -f build.xml-org; then
        kmk_mv -v -- build.xml build.xml-org
    fi
    kmk_cat > sed.frag.source-ver <<EOF
          source="8"
EOF
    kmk_sed -e '/<javac srcdir.* destdir.*/r sed.frag.source-ver' --output build.xml build.xml-org
    run_ant

    # Manual install into repo - xml-apis
    kmk_mkdir -p -- "${MY_MAVEN_REPO_DIR}/xml-apis/xml-apis/1.4.01/"
    kmk_cp -v -- build/xml-apis.jar "${MY_MAVEN_REPO_DIR}/xml-apis/xml-apis/1.4.01/xml-apis-1.4.01.jar"
    kmk_cat                       > "${MY_MAVEN_REPO_DIR}/xml-apis/xml-apis/1.4.01/xml-apis-1.4.01.pom" <<EOF
<project>
  <modelVersion>4.0.0</modelVersion>
  <groupId>xml-apis</groupId>
  <artifactId>xml-apis</artifactId>
  <name>XML Commons External Components XML APIs</name>
  <version>1.4.01</version>
  <properties>
    <PLSApproval>Approved</PLSApproval>
    <PLSBussAprID>8286</PLSBussAprID>
    <PLS3rdPartyID>9334</PLS3rdPartyID>
    <PLSProductApproval>All Products (VP Approval Needed)</PLSProductApproval>
  </properties>
  <description>xml-commons provides an Apache-hosted set of DOM, SAX, and
    JAXP interfaces for use in other xml-based projects. Our hope is that we
    can standardize on both a common version and packaging scheme for these
    critical XML standards interfaces to make the lives of both our developers
    and users easier. The External Components portion of xml-commons contains
    interfaces that are defined by external standards organizations. For DOM,
    that's the W3C; for SAX it's David Megginson and sax.sourceforge.net; for
    JAXP it's Sun.</description>
  <url>http://xml.apache.org/commons/components/external/</url>
  <issueManagement>
    <system>bugzilla</system>
    <url>http://issues.apache.org/bugzilla/</url>
  </issueManagement>
  <mailingLists>
    <mailingList>
      <name>XML Commons Developer's List</name>
      <subscribe>commons-dev-subscribe@xml.apache.org</subscribe>
      <unsubscribe>commons-dev-unsubscribe@xml.apache.org</unsubscribe>
      <post>commons-dev@xml.apache.org</post>
      <archive>http://mail-archives.apache.org/mod_mbox/xml-commons-dev/</archive>
    </mailingList>
  </mailingLists>
  <scm>
    <connection>scm:svn:https://svn.apache.org/repos/asf/xerces/xml-commons/tags/xml-commons-external-1_4_01/</connection>
    <url>https://svn.apache.org/repos/asf/xerces/xml-commons/tags/xml-commons-external-1_4_01/</url>
  </scm>
  <licenses>
    <license>
      <name>The Apache Software License, Version 2.0</name>
      <url>http://www.apache.org/licenses/LICENSE-2.0.txt</url>
      <distribution>repo</distribution>
    </license>
    <license>
      <name>The SAX License</name>
      <url>http://www.saxproject.org/copying.html</url>
      <distribution>repo</distribution>
    </license>
    <license>
      <name>The W3C License</name>
      <url>http://www.w3.org/TR/2004/REC-DOM-Level-3-Core-20040407/java-binding.zip</url>
      <distribution>repo</distribution>
    </license>
  </licenses>
  <developers>
    <developer>
      <id>xml-apis</id>
      <name>Apache Software Foundation</name>
      <email>commons-dev@xml.apache.org</email>
      <url>http://xml.apache.org/commons/</url>
      <organization>Apache Software Foundation</organization>
      <organizationUrl>http://www.apache.org</organizationUrl>
    </developer>
  </developers>
</project>
EOF

    # Manual install into repo - xml-apis-ext
    kmk_mkdir -p -- "${MY_MAVEN_REPO_DIR}/xml-apis/xml-apis-ext/1.4.01/"
    kmk_cp -v -- build/xml-apis-ext.jar "${MY_MAVEN_REPO_DIR}/xml-apis/xml-apis-ext/1.4.01/xml-apis-ext-1.4.01.jar"
    kmk_cat                           > "${MY_MAVEN_REPO_DIR}/xml-apis/xml-apis-ext/1.4.01/xml-apis-ext-1.4.01.pom" <<EOF
<project>
  <parent>
    <artifactId>apache</artifactId>
    <groupId>org.apache</groupId>
    <version>3</version>
  </parent>
  <properties>
    <PLSApproval>Approved</PLSApproval>
    <PLSBussAprID>74888</PLSBussAprID>
    <PLS3rdPartyID>9334</PLS3rdPartyID>
    <PLSProductApproval>Oracle Jdeveloper</PLSProductApproval>
  </properties>
  <modelVersion>4.0.0</modelVersion>
  <groupId>xml-apis</groupId>
  <artifactId>xml-apis-ext</artifactId>
  <name>XML Commons External Components XML APIs Extensions</name>
  <version>1.4.01</version>
  <description>xml-commons provides an Apache-hosted set of DOM, SAX, and JAXP interfaces
    for use in other xml-based projects. Our hope is that we can standardize on both a common
    version and packaging scheme for these critical XML standards interfaces to make the lives
    of both our developers and users easier. The External Components portion of xml-commons
    contains interfaces that are defined by external standards organizations. For DOM, that's
    the W3C; for SAX it's David Megginson and sax.sourceforge.net; for JAXP it's Sun.</description>
  <url>http://xml.apache.org/commons/components/external/</url>
  <issueManagement>
    <system>bugzilla</system>
    <url>http://issues.apache.org/bugzilla/</url>
  </issueManagement>
  <mailingLists>
    <mailingList>
      <name>XML Commons Developer's List</name>
      <subscribe>commons-dev-subscribe@xml.apache.org</subscribe>
      <unsubscribe>commons-dev-unsubscribe@xml.apache.org</unsubscribe>
      <post>commons-dev@xml.apache.org</post>
      <archive>http://mail-archives.apache.org/mod_mbox/xml-commons-dev/</archive>
    </mailingList>
  </mailingLists>
  <scm>
    <connection>scm:svn:https://svn.apache.org/repos/asf/xerces/xml-commons/tags/xml-commons-external-1_4_01/</connection>
    <url>https://svn.apache.org/repos/asf/xerces/xml-commons/tags/xml-commons-external-1_4_01/</url>
  </scm>
  <distributionManagement>
    <status>deployed</status>
  </distributionManagement>
</project>
EOF
}

# Get, set up and build the desired Apache commons-io package.
# Note! Skipping tests as 1 or two fails.
# Note! This is using version 2.8.2 of the deploy plugin, which requires the repository
#       type (default (=maven2)) to be given with the altDeploymentRepository option.
get_and_setup_and_build_commons_io()
{
    download_and_unpack_in_bld_root "fb7f1814132cd44c4c1277a70831228f" "commons-io-2.8.0-src.zip" "https://archive.apache.org/dist/commons/io/source/"
    cd "${MY_BLD_DIR}/commons-io-2.8.0-src/"
    #kmk_mv -v -- pom.xml pom.xml-org
    #kmk_sed \
    #    -e 's/<maven\.compiler\.source>1\.8<\/maven\.compiler\.source>/<maven.compiler.source>17<\/maven.compiler.source>/' \
    #    -e 's/<maven\.compiler\.target>1\.8<\/maven\.compiler\.target>/<maven.compiler.target>17<\/maven.compiler.target>/' \
    #    --output pom.xml pom.xml-org
    run_mvn deploy "-DaltDeploymentRepository=release-repo::default::file:///${MY_MAVEN_REPO_DIR}" "-DskipTests"
}

# Get, set up and build the desired google guava version (25.1-jre)
# Note! Unit tests uses package java.security.acl which was remove in JDK ~14,
#       so we drop the guava-tests module.  This means we need to drop guava-gwt
#       as well.
get_and_setup_and_build_guava()
{
    download_and_unpack_in_bld_root "43420e3134db52cb6c4a4716ca906424" "guava-25.1.zip" "https://github.com/google/guava/archive/refs/tags/" "v25.1.zip"
    cd "${MY_BLD_DIR}/guava-25.1/"
    if ! test -f pom.xml-org; then
        kmk_mv -v -- pom.xml pom.xml-org
    fi
    kmk_sed \
        -e '/<module>guava-tests<\/module>/d' \
        -e '/<module>guava-gwt<\/module>/d' \
        --output pom.xml pom.xml-org

    # Turns out it guava-gwt really needs guava-tests.
    #if ! test -f guava-gwt/pom.xml-org; then
    #    kmk_mv -v -- guava-gwt/pom.xml guava-gwt/pom.xml-org
    #fi
    #kmk_sed \
    #    -e '/<dependency>/bdeploop' \
    #    -e '/<execution>/bexeloop' \
    #    -e 'bdone' \
    #    \
    #    -e ':deploop' \
    #    -e 'N' \
    #    -e '/<\/dependency>/!bdeploop' \
    #    -e 'bfilter' \
    #    \
    #    -e ':exeloop' \
    #    -e 'N' \
    #    -e '/<\/execution>/!bexeloop' \
    #    \
    #    -e ':filter' \
    #    -e '/guava-tests/d' \
    #    -e ':done' \
    #    \
    #    --output guava-gwt/pom.xml guava-gwt/pom.xml-org

    run_mvn deploy "-DaltDeploymentRepository=release-repo::default::file:///${MY_MAVEN_REPO_DIR}" "-DskipTests"
}

# Get, set up and build the iso-relax 2003-08-01.
#
# This is very old w/o any build script, so we do it manually and cobble it together.
# The archive w/o directories and the sources are nested inside it.
get_and_setup_and_build_isorelax()
{
    #download "c95dce97fde4bf3b9a2156bac8da85c0" "isorelax.20030108.zip" "https://master.dl.sourceforge.net/project/iso-relax/package/2003_01_08/" "isorelax.20030108.zip?viasf=1"
    #unpack_in_dir "${MY_DOWNLOAD_DIR}/isorelax.20030108.zip" "isorelax-20030108"
    #cd "${MY_BLD_DIR}/isorelax-20030108"
    #7z x src.zip

    kmk_mkdir -p -- "${MY_BLD_DIR}/isorelax-20030108"

    # We need CVSNT here so we can check out the sources w/ build script and dependencies (only 1.12.13a and cvnnt works for me).
    #download "d43dba3dbd7d3a9f4c3f61d79205684a" "cvs-1-12-13a.zip" "https://ftp.gnu.org/non-gnu/cvs/binary/feature/x86-woe/"
    download "534143d48d646cf8b450b60fe1d390e7" "cvsnt-legacy-20170126.zip" "https://master.dl.sourceforge.net/project/cvsnt-legacy/" "cvsnt-legacy-20170126.zip?viasf=1"

    # For proxying we need socat.
    download "e54b122ebc3646b042a6f5b3ae8ab256" "socat-1.7.3.2-1-x86_64.zip" "https://master.dl.sourceforge.net/project/unix-utils/socat/1.7.3.2/" "socat-1.7.3.2-1-x86_64.zip?viasf=1"

    cd "${MY_BLD_DIR}/isorelax-20030108/"
    #7z x "${MY_DOWNLOAD_DIR}/cvs-1-12-13a.zip"
    7z x "${MY_DOWNLOAD_DIR}/cvsnt-legacy-20170126.zip"
    7z e "${MY_DOWNLOAD_DIR}/socat-1.7.3.2-1-x86_64.zip"
    ./cvs.exe --version > /dev/null

    # Check out the sources from the sourceforget site.
    kmk_mkdir -p -- "${MY_BLD_DIR}/isorelax-20030108/wc"
    cd              "${MY_BLD_DIR}/isorelax-20030108/wc"
    if test -z "${MY_PROXY}"; then
        ../cvs.exe -z6 -d:pserver:anonymous@iso-relax.cvs.sourceforge.net:/cvsroot/iso-relax co -r release-20030108 .
    else
        kkill socat.exe || test 1
        ../socat.exe TCP4-LISTEN:2401,fork PROXY:www-proxy-ams.nl.oracle.com:iso-relax.cvs.sourceforge.net:2401,proxyport=80 &
        ../cvs.exe -z6 -d:pserver:anonymous@localhost:/cvsroot/iso-relax co -r release-20030108 .
        kkill socat.exe || test 1
    fi

    # Patch ValidatingDocumentBuilderFactory.java so it builds with JDK 1.6 and later.
    kmk_cat > sed.frag.feature <<EOF
    /* Added in 1.6 */
    public boolean getFeature(String name) throws ParserConfigurationException
    {
        throw new ParserConfigurationException("getFeature("+name+") not implemented");
    }
    public void setFeature(String name, boolean value) throws ParserConfigurationException
    {
        throw new ParserConfigurationException("setFeature("+name+", "+String.valueOf(value)+") not implemented");
    }
EOF
    if ! test -f src/org/iso_relax/jaxp/ValidatingDocumentBuilderFactory.java-org; then
        kmk_mv -v -- src/org/iso_relax/jaxp/ValidatingDocumentBuilderFactory.java \
                     src/org/iso_relax/jaxp/ValidatingDocumentBuilderFactory.java-org
    fi
    kmk_sed -e '/_WrappedFactory\.setNamespaceAware/r sed.frag.feature' \
        --output src/org/iso_relax/jaxp/ValidatingDocumentBuilderFactory.java \
        src/org/iso_relax/jaxp/ValidatingDocumentBuilderFactory.java-org

    # Patch the build file to look at our ant.jar before the <=2003 ant stuff in lib.
    kmk_cat > sed.frag.classpath <<EOF
				>
			<classpath>
				<pathelement path="${MY_BLD_DIR}/apache-ant-1.10.12/build/lib/ant.jar"/>
				<pathelement path="lib/verifier.jar"/>
			</classpath>
EOF

    if ! test -f build.xml-org; then mv -v -- build.xml build.xml-org; fi
    kmk_sed -e '/classpath=/r sed.frag.classpath' -e '/classpath=/d' --output build.xml build.xml-org

    # build them using ant.
    run_ant

    # Deploy it.
    kmk_mkdir -p -- "${MY_MAVEN_REPO_DIR}/isorelax/isorelax/20030108/"
    kmk_cp -v -- isorelax.jar "${MY_MAVEN_REPO_DIR}/isorelax/isorelax/20030108/isorelax-20030108.jar"
    kmk_cat                 > "${MY_MAVEN_REPO_DIR}/isorelax/isorelax/20030108/isorelax-20030108.pom" <<EOF
<project>
  <modelVersion>4.0.0</modelVersion>
  <groupId>isorelax</groupId>
  <artifactId>isorelax</artifactId>
  <version>20030108</version>
  <description>The ISO RELAX project is started to host the public interfaces useful for
    applications to support RELAX Core. But nowadays some of the stuff we have is schema
    language neutral. All the source code and binaries are available under the MIT license
    (see inside the distribution jar file for details.)</description>
  <url>https://iso-relax.sourceforge.net/</url>
  <licenses>
    <license>
      <name>MIT</name>
      <url>http://www.opensource.org/licenses/mit-license.html</url>
    </license>
  </licenses>
  <dependencies/>
</project>
EOF
}

# Get, set up and build the desired jing(-trang) version.
# Note! Using the ant version shipping with the source, getting into classpath issues otherwise.
get_and_setup_and_build_jing_trang()
{
    download_and_unpack_in_bld_root "da6dcb642372f4350d6fedfe3468468b" "jing-trang-v20181222.zip" "https://github.com/relaxng/jing-trang/archive/refs/tags/" "V20181222.zip"
    cd "${MY_BLD_DIR}/jing-trang-20181222/"

    # We dont need the docs and we don't have git to fetch them anyway.
    if ! test -f build.xsl-org; then kmk_mv -v -- build.xsl build.xsl-org; fi
    kmk_sed \
        -e '/<exec executable="git">/,/<\/copy>/{d}' \
        --output build.xsl build.xsl-org

    # javadoc fails when run via maven-jing/trang.xml, so disable it. we don't care about docs here.
    if ! test -f maven-jing.xml-org; then kmk_mv -v -- maven-jing.xml maven-jing.xml-org; fi
    kmk_sed \
        -e 's/depends="javadoc-jar,sources-jar"/depends="sources-jar"/' \
        --output maven-jing.xml maven-jing.xml-org

    if ! test -f maven-trang.xml-org; then kmk_mv -v -- maven-trang.xml maven-trang.xml-org; fi
    kmk_sed \
        -e 's/depends="javadoc-jar,sources-jar"/depends="sources-jar"/' \
        --output maven-trang.xml maven-trang.xml-org

    # Build
    cmd /C ant.bat
    cmd /C ant.bat dtdinst-dist
    cmd /C ant.bat jing-dist  || true # This runs into trouble with docs, but it has done sufficient for packaging and deployment.
    cmd /c ant.bat trang-dist

    # Package
    cmd /C ant.bat -Dversion=20181222 -f maven-jing.xml -d artifacts
    cmd /C ant.bat -Dversion=20181222 -f maven-trang.xml -d artifacts

    # Deploy
    run_mvn deploy:deploy-file -Dfile=build/dist/jing-20181222.jar  -DpomFile=build/dist/jing-20181222.pom  "-Durl=file:///${MY_MAVEN_REPO_DIR}" -DrepositoryId=MavenLocalStaging
    run_mvn deploy:deploy-file -Dfile=build/dist/trang-20181222.jar -DpomFile=build/dist/trang-20181222.pom "-Durl=file:///${MY_MAVEN_REPO_DIR}" -DrepositoryId=MavenLocalStaging
}


# Get, set up and build the desired Apache fop-pdf-images package.
get_and_setup_and_build_fop_pdf_images()
{
    # The official dist does not include the pom template file and is missing five jar files
    # under lib/build, so we just get the lovely thing from the svn repo.
    #download_and_unpack_in_bld_root "" "fop-pdf-images-2.6-src.zip" "https://archive.apache.org/dist/xmlgraphics/fop-pdf-images/source/"
    cd "${MY_BLD_DIR}"
    svn ${MY_SVN_PROXY_OPTS} export \
        https://svn.apache.org/repos/asf/xmlgraphics/fop-pdf-images/tags/fop-pdf-images-2_6/ \
        fop-pdf-images-2.6
    cd "${MY_BLD_DIR}/fop-pdf-images-2.6/"

    # Disable signing and passphrase input in build.xml.
    if ! test -f build.xml-org; then mv -v -- build.xml build.xml-org; fi
    kmk_sed \
        -e '/<input message=/,/<\/input>/{d}' \
        -e '/<antcall target=.sign-file./,/<\/antcall>/{d}' \
        --output build.xml build.xml-org

    # Use the ant build file, not the maven one as it produces org.apache.fop.render.pdf.pdfbox:fop-pdf-images:2.6
    # instead of org.apache.xmlgraphics:fop-pdf-images:2.6.
    #run_mvn deploy "-DaltDeploymentRepository=release-repo::file:///${MY_MAVEN_REPO_DIR}" "-DskipTests"
    #run_ant package
    run_ant maven-artifacts

    # Copy the artifacts to the staging repo.
    cd build                                # avoids it finding pom.xml
    run_mvn deploy:deploy-file \
        -Dfile=fop-pdf-images-2.6.jar \
        -Dsources=fop-pdf-images-2.6-sources.jar \
        -Djavadoc=fop-pdf-images-2.6-javadoc.jar \
        -DpomFile=maven/pom.xml \
        "-Durl=file:///${MY_MAVEN_REPO_DIR}" -DrepositoryId=MavenLocalStaging
}


# Rebuilt the dita-index plugin as it includes class files.
get_and_unpack_and_build_dita_index()
{
    download_and_unpack_in_bld_root "c2e6d60d495106a2d15be8ea3d54843d" "org.dita.index-1.0.0.zip" "https://github.com/dita-ot/org.dita.index/archive/refs/tags/" "1.0.0.zip"
    cd "${MY_BLD_DIR}/org.dita.index-1.0.0/"

    # The build.gradle file does not work with our newer gradle version, it is also
    # missing dependencies and stuff, so just replace it.
    if ! test build.gradle-org; then kmk_mv -v -- build.gradle build.gradle-org; fi
    kmk_cat > build.gradle <<EOF
/*
 * This file is part of the DITA Open Toolkit project.
 *
 * Copyright 2019 Jarno Elovirta
 * Copyright 2023 Oracle
 *
 * See the accompanying LICENSE file for applicable license.
 */
apply plugin: 'java'
apply plugin: "maven-publish"
group = 'org.dita-ot'
version = '1.0.0'
description = """DITA Open Toolkit indexing plug-in."""
sourceCompatibility = 17
targetCompatibility = 17
repositories {
    maven {
        name "MavenLocalStaging"
        url  "file:///E:/vbox/dita-ot/repo-maven/"
    }
    maven {
        name "OscsOciOracleDist"
        url  "https://artifacthub-phx.oci.oraclecorp.com/oscs-oci-oracledist/"
    }
    flatDir {
        name "FlatDirRepo"
        dirs "E:/vbox/dita-ot/repo-flat"
    }
    mavenCentral()
}
dependencies {
    implementation group: 'org.dita-ot', name: 'dost', version: '[3.4,4.0)'
    implementation group: 'org.apache.ant', name: 'ant', version:'1.10.12'
    implementation group: 'com.ibm.icu', name: 'icu4j', version:'70.1'
    implementation(group: 'com.google.guava', name: 'guava', version: '25.1-jre') {
        exclude group: 'org.checkerframework', module: 'checker-qual'
        exclude group: 'org.codehaus.mojo', module: 'animal-sniffer-annotations'
        exclude group: 'com.google.code.findbugs', module: 'jsr305'
        exclude group: 'com.google.errorprone', module: 'error_prone_annotations'
        exclude group: 'com.google.j2objc', module: 'j2objc-annotations'
    }
    implementation group: 'org.slf4j', name: 'slf4j-api', version: '1.7.32'
    implementation group: 'net.sf.saxon', name: 'Saxon-HE', version: '10.5'

    testImplementation group: 'junit', name: 'junit', version: '4.12'
    testImplementation group: 'org.xmlunit', name: 'xmlunit-core', version: '2.6.3'
    testImplementation group: 'org.xmlunit', name: 'xmlunit-matchers', version: '2.6.3'
}
sourceSets {
    main {
        resources {
            exclude 'build.xml'
            exclude 'messages.xml'
            exclude 'plugin.xml'
        }
    }
}
compileJava.options.encoding = 'UTF-8'
compileTestJava.options.encoding = "UTF-8"
jar.setArchiveFileName "\${project.name}.jar"
task copyInstall(type: Copy) {
    from(configurations.runtimeOnly.allArtifacts.files)
    destinationDir = file("lib")
}
task dist(type: Zip, dependsOn: [jar]) {
    into("lib") {
        from ("build/libs") {
            include "*.jar"
        }
    }
    into("") {
        from("src/main/resources") {
            include "plugin.xml"
            expand(
                    version: project.version,
                    jar:     "\${project.name}.jar" // jar.getArchiveFileName() - wtf?
            )
        }
        from("src/main/resources") {
            include "build.xml"
            include "index/*"
            include "messages.xml"
        }
        from(".") {
            include "LICENSE"
        }
    }
    setArchiveFileName "org.dita.\${project.name}-\${project.version}.zip"
}
EOF

    # Build and copy to staging repo.
    run_gradle -i -d
    run_gradle -i dist
}
MY_DITA_INDEX_ZIP="${MY_BLD_DIR}/org.dita.index-1.0.0/build/distributions/org.dita.index-1.0.0.zip"

# Get, set up and build a more recent version of the pdf-generator.
# We need mid Feb 2023 or later. Going for commit 50727683bcf7a75c3410eda19cdf79b308aae031.
get_and_unpack_and_build_pdf_generator()
{
    download_and_unpack_in_bld_root "4a80c2addcfeefb130649057c42062e3" "pdf-generator-50727683bcf7a75c3410eda19cdf79b308aae031.zip" "https://github.com/jelovirt/pdf-generator/archive/" "50727683bcf7a75c3410eda19cdf79b308aae031.zip"
    cd "${MY_BLD_DIR}/pdf-generator-50727683bcf7a75c3410eda19cdf79b308aae031/"
    kmk_mv -v -- build.gradle build.gradle-org
    kmk_sed \
        -e 's/\(Compatibility *= *\)1.8/\117/' \
        --output build.gradle build.gradle-org
    run_gradle -i
    run_gradle -i dist
}
MY_PDF_GENERATOR_ZIP="${MY_BLD_DIR}/pdf-generator-50727683bcf7a75c3410eda19cdf79b308aae031/build/distributions/com.elovirta.pdf.zip"


# Helper for get_and_unpack_and_build_dita_ot that checks the resuling jar files against
# the virgin+maven-central build.  Adds files that doesn't confirm to MY_JARS_TAINED and
# okay ones to MY_JARS_OKAY.
check_dita_ot_jar_files()
{
    while test $# -gt 0;
    do
        # We append both the crc and the date+time to the member name so we may
        # (hopefully) catch stuff from maven-central and such w/o false positives.
        # The java compiler produces identical files, but we hope the timestamp
        # might be preserved if .class files are copied around (a bit doubtful).
        MY_CLASS_MEMBERS=$( \
            LC_ALL=C unzip -v "$1" \
            | kmk_sed \
                -e '/.class$/!d' \
                -e 's/\$/@/g' \
                -e 's/^.* \([0-9]*-[0-9]*-[0-9]*\) \([0-9][:0-9]*\)  \([[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]]\)  \([^ ][^ ]*\.class\)$/\4:\1T\2:crc:\3/' \
        )
        if test -z "${MY_CLASS_MEMBERS}"; then
            echo "inf: Jar file is okay: $1 (no class files)"
            MY_JARS_OKAY="${MY_JARS_OKAY} $1"
        elif kmk_cmp -s -- "$1" "${MY_BLD_DIR}/dita-ot-4.0.2-virgin/$1"; then
            echo "error: Jar file is tainted: $1" #>&2 #- this redirect is trouble when tee'ing! WTF?
            MY_JARS_TAINED="${MY_JARS_TAINED} $1"
        else
            # Check that all the .class files differs (hoping that javac won't produce the same bytecode).
            MY_CLASS_MEMBERS_VIRGIN=$( \
                unzip -v "${MY_BLD_DIR}/dita-ot-4.0.2-virgin/$1" \
                | kmk_sed \
                    -e '/.class$/!d' \
                    -e 's/\$/@/g' \
                    -e 's/^.* \([0-9]*-[0-9]*-[0-9]*\) \([0-9][:0-9]*\)  \([[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]]\)  \([^ ][^ ]*\.class\)$/\4:\1T\2:crc:\3/' \
            )
            MY_MATCHING_CLASSES=
            for class in ${MY_CLASS_MEMBERS};
            do
                for virginclass in ${MY_CLASS_MEMBERS_VIRGIN};
                do
                    if test "${virginclass}" = "${class}"; then
                        MY_MATCHING_CLASSES="${MY_MATCHING_CLASSES} ${class}"
                    fi
                done
            done
            if test -z "${MY_MATCHING_CLASSES}"; then
                echo "inf: Jar file is okay: $1"
                MY_JARS_OKAY="${MY_JARS_OKAY} $1"
            else
                MY_JARS_TAINED="${MY_JARS_TAINED} $1"
                echo "error: Jar file is tainted: $1" #>&2 - just in case, see above
                for class in ${MY_MATCHING_CLASSES};
                do
                    echo "error:   member: ${class}" #>&2 - just in case, see above
                done
            fi
        fi
        shift
    done
}

check_dita_ot_jar_files_in_dir_if_exists()
{
    if test -d "$1"; then
        check_dita_ot_jar_files "$1/"*.jar
    fi
}

#
# Get and build the DITA-OT source package as-is, w/o any special repos changes.
#
# This will be used for comparison to make sure we've rebuilt all the jars and
# their class files.
#
get_and_unpack_and_build_virgin_dita_ot()
{
    # first the virgin copy:  - build before everything else.
    download_and_unpack_in_bld_root "6f4fba971414f41031395009e0692fe6" "dita-ot-4.0.2-src.zip" "https://github.com/dita-ot/dita-ot/archive/refs/tags/" "4.0.2.zip"
    kmk_mv -v -- "${MY_BLD_DIR}/dita-ot-4.0.2" "${MY_BLD_DIR}/dita-ot-4.0.2-virgin"
    cd "${MY_BLD_DIR}/dita-ot-4.0.2-virgin"
    run_gradle -x test -PskipGenerateDocs=true -i
    run_gradle -x test -PskipGenerateDocs=true -q dependencies # for debugging/comparing
    run_gradle -x test -PskipGenerateDocs=true -i dist
}

#
# Get, set up and build the DITA-OT source package we intend to use.
#
# We compare the resulting jar-files with the virgin build to make sure we're
#  not using anything from maven-central.
#
# Note! We skip the src/main/docsrc bits for now as it's not included and
#       people can go online to find this info (see .gitmodules).
#
# Note! Following dependency version adjustments:
#          - ch.qos.logback:logback-classic: 1.2.8 -> 1.2.12
#          - net.sf.saxon:Saxon-HE: 10.6 -> 10.5 (available in OscsOciOracleDist,
#            seems to be a real pain to rebuild)
#
get_and_unpack_and_build_dita_ot()
{
    # The actual build we want to use.
    unpack_in_bld_root "${MY_DOWNLOAD_DIR}/dita-ot-4.0.2-src.zip"
    kmk_mv -v -- "${MY_BLD_DIR}/dita-ot-4.0.2" "${MY_BLD_DIR}/dita-ot-4.0.2-build"
    cd "${MY_BLD_DIR}/dita-ot-4.0.2-build"
    if ! test -f build.gradle-org; then
        kmk_mv -v -- build.gradle build.gradle-org
    fi
    kmk_cat > sed.frag.distros <<EOF
allprojects {
    repositories {
        maven {
            name "MavenLocalStaging"
            url  "file:///${MY_MAVEN_REPO_DIR}/"
        }
        maven {
            name "OscsOciOracleDist"
            url  "https://artifacthub-phx.oci.oraclecorp.com/oscs-oci-oracledist/"
        }
        flatDir {
            name "FlatDirRepo"
            dirs "${MY_FLAT_REPO_DIR}"
        }
    }
}
EOF
    kmk_cat > sed.frag.our.repos <<EOF
    maven {
        name "MavenLocalStaging"
        url  "file:///${MY_MAVEN_REPO_DIR}/"
    }
    maven {
        name "OscsOciOracleDist"
        url  "https://artifacthub-phx.oci.oraclecorp.com/oscs-oci-oracledist/"
    }
    flatDir {
        name "FlatDirRepo"
        dirs "${MY_FLAT_REPO_DIR}"
    }
EOF

    kmk_cat > sed.frag.theme-and-index <<EOF
        "index": "file:///${MY_DITA_INDEX_ZIP}",
        "theme": "file:///${MY_PDF_GENERATOR_ZIP}",
EOF
    kmk_sed \
        -e '/"eclipsehelp":/d' \
        -e '/"markdown":/d' \
        -e '/"axf":/d' \
        -e '/"xep":/d'\
        -e '/"index":/d' \
        -e '/"theme":/r sed.frag.theme-and-index' \
        -e '/"theme":/d' \
        -e '/^targetCompatibility/r sed.frag.distros' \
        -e 's/\(implementation group: *.ch\.qos\.logback., *name: *.logback-classic., *version: *.\)1\.2\.8/\11.2.11/' \
        -e 's/\(implementation group: *.net.sf.saxon., *name: *.Saxon-HE., *version: *.\)10\.6/\110.5/' \
        --output build.gradle build.gradle-org
    #diff -u build.gradle-org build.gradle || true

    # Tweaks for the htmlhelp gradle file:
    #  - Supplement the repositories.
    #  - Saxon-HE version.
    if ! test -f src/main/plugins/org.dita.htmlhelp/build.gradle-org; then
        kmk_mv -v -- src/main/plugins/org.dita.htmlhelp/build.gradle  src/main/plugins/org.dita.htmlhelp/build.gradle-org
    fi
    kmk_sed \
        -e '/^repositories *{$/r sed.frag.our.repos' \
        -e 's/\(implementation group: *.net.sf.saxon., *name: *.Saxon-HE., *version: *.\)10\.6/\110.5/' \
        --output src/main/plugins/org.dita.htmlhelp/build.gradle  src/main/plugins/org.dita.htmlhelp/build.gradle-org

    # Tweaks for the pdf2 gradle file:
    #  - Supplement the repositories.
    #  - Saxon-HE version.
    if ! test -f src/main/plugins/org.dita.pdf2/build.gradle-org; then
        kmk_mv -v -- src/main/plugins/org.dita.pdf2/build.gradle  src/main/plugins/org.dita.pdf2/build.gradle-org
    fi
    kmk_sed \
        -e '/^repositories *{$/r sed.frag.our.repos' \
        -e 's/\(implementation group: *.net.sf.saxon., *name: *.Saxon-HE., *version: *.\)10\.6/\110.5/' \
        --output src/main/plugins/org.dita.pdf2/build.gradle  src/main/plugins/org.dita.pdf2/build.gradle-org

    # Tweaks for the pdf2.fop gradle file:
    #  - Supplement the repositories.
    #  - The difference between xml-apis-ext 1.3.04 and 1.4.01 is treating an empty property value same as null
    #    in DOMImplementationRegistry::newInstance, and a new ElementTraversal.java file.  So, use just 1.4.01.
    if ! test -f src/main/plugins/org.dita.pdf2.fop/build.gradle-org; then
        kmk_mv -v -- src/main/plugins/org.dita.pdf2.fop/build.gradle  src/main/plugins/org.dita.pdf2.fop/build.gradle-org
    fi
    kmk_sed \
        -e '/^repositories *{$/r sed.frag.our.repos' \
        -e 's/\(runtimeOnly  *group: *.xml-apis., *name: *.xml-apis-ext., *version: *.\)1.3.04/\11.4.01/' \
        --output src/main/plugins/org.dita.pdf2.fop/build.gradle  src/main/plugins/org.dita.pdf2.fop/build.gradle-org

    # Ditto for org.dita.pdf2.fop/plugin.xml ...
    if ! test -f src/main/plugins/org.dita.pdf2.fop/plugin.xml-org; then
        kmk_mv -v -- src/main/plugins/org.dita.pdf2.fop/plugin.xml  src/main/plugins/org.dita.pdf2.fop/plugin.xml-org
    fi
    kmk_sed \
        -e 's,lib/xml-apis-ext-1\.3\.04\.jar,lib/xml-apis-ext-1.4.01.jar,' \
        --output src/main/plugins/org.dita.pdf2.fop/plugin.xml  src/main/plugins/org.dita.pdf2.fop/plugin.xml-org

    # ... and src/test/resources/plugins.xml.
    if ! test -f src/test/resources/plugins.xml-org; then
        kmk_mv -v -- src/test/resources/plugins.xml  src/test/resources/plugins.xml-org
    fi
    kmk_sed \
        -e 's,lib/xml-apis-ext-1\.3\.04\.jar,lib/xml-apis-ext-1.4.01.jar,' \
        --output src/test/resources/plugins.xml  src/test/resources/plugins.xml-org

    # We tweak the dist.gradle file because something is incorrectly dragging in junit and its hamcrest-core dep.
    if ! test -f gradle/dist.gradle-org; then
        kmk_mv -v -- gradle/dist.gradle gradle/dist.gradle-org
    fi
    kmk_cat > sed.frag.license_hack_bogus_deps <<EOF
        [name: 'hamcrest-core'],
        [name: 'junit'],
EOF
    kmk_sed \
        -e '/def  *licenses *= *\[/r sed.frag.license_hack_bogus_deps' \
        --output gradle/dist.gradle gradle/dist.gradle-org

    # Patch buggy htmlhelp plugin.
    if ! test -f src/main/plugins/org.dita.htmlhelp/build_dita2htmlhelp_template.xml-org; then
        kmk_mv -v -- src/main/plugins/org.dita.htmlhelp/build_dita2htmlhelp_template.xml \
                     src/main/plugins/org.dita.htmlhelp/build_dita2htmlhelp_template.xml-org
    fi
    kmk_cat > sed.frag.fix4181 <<EOF
    <!-- <property name="preprocess.copy-image.skip" value="true"/> - https://github.com/dita-ot/dita-ot/issues/4181 -->
    <property name="build-step.copy-image" value="false"/>
EOF
    kmk_sed \
        -e '/<property  *name=.preprocess\.copy-image\.skip.  *value=.true/r sed.frag.fix4181' \
        -e '/<property  *name=.preprocess\.copy-image\.skip.  *value=.true/d' \
        --output src/main/plugins/org.dita.htmlhelp/build_dita2htmlhelp_template.xml \
        src/main/plugins/org.dita.htmlhelp/build_dita2htmlhelp_template.xml-org

    # Apply the patch that reduce the single-html job from ~4m20s to ~40s.
    if ! test -f dita-ot-bld-single-html-optimization-v0.applied; then
        patch --dry-run -p1 -i ../dita-ot-bld-single-html-optimization-v0.diff
        patch           -p1 -i ../dita-ot-bld-single-html-optimization-v0.diff
        kmk_cp -- ../dita-ot-bld-single-html-optimization-v0.diff dita-ot-bld-single-html-optimization-v0.applied
    fi

    # Build.
    run_gradle -x test -PskipGenerateDocs=true -i
    run_gradle -x test -PskipGenerateDocs=true -q dependencies # for debugging/comparing
    run_gradle -x test -PskipGenerateDocs=true -i dist

    # Check jar files (relative paths!).
    set +x
    echo "info: Checkin the jar files..."
    MY_JARS_OKAY=
    MY_JARS_TAINED=
    check_dita_ot_jar_files                  build/tmp/dist/lib/*jar
    check_dita_ot_jar_files_in_dir_if_exists build/tmp/dist/plugins/com.elovirta.pdf/lib
    check_dita_ot_jar_files_in_dir_if_exists build/tmp/dist/plugins/org.dita.htmlhelp/lib
    check_dita_ot_jar_files_in_dir_if_exists build/tmp/dist/plugins/org.dita.index/lib
    check_dita_ot_jar_files_in_dir_if_exists build/tmp/dist/plugins/org.dita.pdf2/lib
    check_dita_ot_jar_files_in_dir_if_exists build/tmp/dist/plugins/org.dita.pdf2.axf/lib
    check_dita_ot_jar_files_in_dir_if_exists build/tmp/dist/plugins/org.dita.pdf2.fop/lib
    check_dita_ot_jar_files_in_dir_if_exists build/tmp/dist/plugins/org.dita.pdf2.xep/lib
    check_dita_ot_jar_files_in_dir_if_exists build/tmp/dist/plugins/org.lwdita/lib
    echo "info: Okay jar files:"
    for jar in ${MY_JARS_OKAY}; do
        echo "info:     ${jar}" #>&2 - just in case, see above
    done
    if test -n "${MY_JARS_TAINED}"; then
        echo "error:" #>&2 - just in case, see above
        echo "error: Tained jars:" #>&2 - just in case, see above
        for jar in ${MY_JARS_TAINED}; do
            echo "error:    ${jar}" #>&2 - just in case, see above
        done
        exit 1
    fi
    set -x
}

# Repackage the dita-ot package, stripping of the top directory and adding our
# three files.
repackage_dita_ot()
{
    kmk_mkdir -- "${MY_BLD_DIR}/repackage"
    cd "${MY_BLD_DIR}/repackage"
    7z x "${MY_BLD_DIR}/dita-ot-4.0.2-build/build/distributions/dita-ot-4.0.2.zip"
    cd dita-ot-4.0.2
    kmk_cp -- ${MY_BLD_DIR}/readme.tool        ./
    kmk_cp -- ${MY_BLD_DIR}/dita-ot-bld.sh     ./
    kmk_cp -- ${MY_BLD_DIR}/dita-ot-bld.cmd    ./
    kmk_cp -- ${MY_BLD_DIR}/dita-ot-bld-*.diff ./
    7z a -mx=9 -r ${MY_BLD_DIR}/common.dita-ot.v4.0.2-r1.7z .
    kmk_md5sum -b ${MY_BLD_DIR}/common.dita-ot.v4.0.2-r1.7z
}


#
# Build steps. Comment out to skip stuff when resuming after fixing an issue.
#

# Layout and build tools:
create_layout
get_and_install_gradle
get_and_install_maven
get_and_setup_and_build_ant 'tool'

# Do a virgin build of dita-ot for reference.
configure_gradle virgin
configure_maven  virgin
get_and_unpack_and_build_virgin_dita_ot

# Reconfigure to non-virgin mode
configure_gradle
configure_maven

# Dependencies:
get_and_setup_and_build_jackson_bom
get_and_setup_and_build_jackson_core
get_and_setup_and_build_jackson_dataformats_text
get_and_setup_and_build_xml_resolver
get_and_setup_and_build_xml_external
get_and_setup_and_build_commons_io
get_and_setup_and_build_jing_trang
get_and_setup_and_build_guava
get_and_setup_and_build_isorelax
get_and_setup_and_build_fop_pdf_images
get_and_setup_and_build_ant 'final'

# DITA stuff:
get_and_unpack_and_build_pdf_generator
get_and_unpack_and_build_dita_index
get_and_unpack_and_build_dita_ot
repackage_dita_ot
