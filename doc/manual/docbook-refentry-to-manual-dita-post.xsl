<?xml version="1.0"?>
<!--
    docbook-refentry-to-manual-dita-pre.xsl:
        XSLT stylesheet for postprocessing a refentry (manpage)
        after converting it to dita for use in the user manual.

    This deals with sep elements containing only spaces, as this
    problematic for the Qt help conversion.
-->
<!--
    Copyright (C) 2006-2026 Oracle and/or its affiliates.

    This file is part of VirtualBox base platform packages, as
    available from https://www.virtualbox.org.

    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation, in version 3 of the
    License.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, see <https://www.gnu.org/licenses>.

    SPDX-License-Identifier: GPL-3.0-only
-->

<xsl:stylesheet
  version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:str="http://xsltsl.org/string"
  >

  <xsl:import href="string.xsl"/>

  <xsl:output method="xml" version="1.0" encoding="utf-8" indent="yes"/>
  <xsl:preserve-space elements="*"/>


<!-- - - - - - - - - - - - - - - - - - - - - - -
  base operation is to copy everything.
 - - - - - - - - - - - - - - - - - - - - - - -->

<xsl:template match="node()|@*">
  <xsl:copy>
     <xsl:apply-templates select="node()|@*"/>
  </xsl:copy>
</xsl:template>


<!-- - - - - - - - - - - - - - - - - - - - - - -
  Deal with sep sibling elements
 - - - - - - - - - - - - - - - - - - - - - - -->

<!-- TODO: merge with adjacent sep objects (a bit complicated).
    In the mean time, hack for space that upsets the html conversion.  -->
<xsl:template match="sep[not(text()[normalize-space(.)] | *)]">
  <xsl:element name="sep">
    <xsl:copy-of select="@*"/>
    <xsl:element name="text">
      <xsl:text> </xsl:text>
    </xsl:element>
  </xsl:element>
</xsl:template>

</xsl:stylesheet>

