# ***** BEGIN LICENSE BLOCK *****
# Version: MPL 1.1
#
# The contents of this file are subject to the Mozilla Public License Version
# 1.1 (the "License"); you may not use this file except in compliance with
# the License. You may obtain a copy of the License at
# http://www.mozilla.org/MPL/
#
# Software distributed under the License is distributed on an "AS IS" basis,
# WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
# for the specific language governing rights and limitations under the
# License.
#
# The Original Code is Tinderbox 3.
#
# The Initial Developer of the Original Code is
# John Keiser (john@johnkeiser.com).
# Portions created by the Initial Developer are Copyright (C) 2004
# the Initial Developer. All Rights Reserved.
#
# Contributor(s):
#
# ***** END LICENSE BLOCK *****

package Tinderbox3::InitialValues;

use strict;

# Tree info
our $field_short_names = 'refcount_leaks=Lk,refcount_bloat=Bl,trace_malloc_leaks=Lk,trace_malloc_maxheap=MH,trace_malloc_allocs=A,pageload=Tp,codesize=Z,xulwinopen=Txul,startup=Ts,binary_url=Binary,warnings=Warn';
our $field_processors = 'refcount_leaks=Graph,refcount_bloat=Graph,trace_malloc_leaks=Graph,trace_malloc_maxheap=Graph,trace_malloc_allocs=Graph,pageload=Graph,codesize=Graph,xulwinopen=Graph,startup=Graph,warnings=Warn,build_zip=URL,raw_zip=URL,installer=URL';
our $statuses = 'open,closed,restricted,metered';
our $min_row_size = 0;
our $max_row_size = 5;
our $default_tinderbox_view = 24*60;
our $new_machines_visible = 1;
our %initial_machine_config = (
  branch => '',
  cvs_co_date => '',
  tests => '',
  cvsroot => '/VBox',
  clobber => 1,
  mozconfig => q^ac_add_options --disable-debug
ac_add_options --enable-optimize
ac_add_options --without-system-nspr
ac_add_options --without-system-zlib
ac_add_options --without-system-png
ac_add_options --without-system-mng
ac_add_options --enable-crypto
^,
);


# Sheriff info
our $header = q^<html>
<head>
<title>Tinderbox - #TREE#</title>
<style>
a img {
  border: 0px
}
body {
  background-color: #DDEEFF
}
table.tinderbox {
  background-color: white;
  width: 100%
}
table.tinderbox td {
  border: 1px solid gray;
  text-align: center;
}
table.tinderbox th {
  border: 1px solid gray;
}
.status0,.status1,.status2,.status3,.status4,.status5,.status6,.status7 {
  background-color: yellow
}
.status10,.status11,.status12,.status13,.status14,.status15,.status16 {
  background-color: gold
}
.status20,.status21 {
  background-color: greenyellow
}
.status100,.status101,.status102,.status103 {
  background-color: lightgreen
}
th.status200,th.status201,th.status202,th.status203 {
  background: url("http://lounge.mozilla.org/tinderbox2/gif/flames1.gif");
  background-color: black;
  color: white
}
th.status200 a,th.status201 a,th.status202 a,th.status203 a {
  color: white
}
.status200,.status201,.status202,.status203 {
  background-color: red
}
.status300,.status301,.status302,.status303 {
  background-color: lightgray
}
.checkin {
  text-align: center
}
.time {
  text-align: right
}
.time_alt {
  text-align: right;
  background-color: #e7e7e7
}
.obsolete {
  text-decoration: line-through
}
#tree_status {
  font-weight: bold;
  padding: 10px
}
#tree_status span {
  font-size: x-large;
}
#tree_top {
  text-align: center;
  vertical-align: middle;
  margin-bottom: 1em;
}
#tree_top span {
  font-size: x-large;
  font-weight: bold
}
#tree_info {
  border-collapse: collapse;
  background-color: white;
  margin-bottom: 1em
}
#tree_info td,th {
  border: 1px solid black
}
#checkin_info {
  border: 1px dashed black;
  background-color: white
}
#info_table td {
  vertical-align: top
}

#popup {
  border: 2px solid black;
  background-color: white;
  padding: 0.5em;
  position: fixed;
}
</style>

<script>
function closepopup() {
  document.getElementById('popup').style.display = 'none';
}
function do_popup(event,_class,str) {
  closepopup();
  var popup = document.getElementById('popup');
  popup.className = _class;
  popup.innerHTML = str;
  popup.style.left = event.clientX;
  popup.style.top = event.clientY;
  popup.style.display = 'block';
  event.stopPropagation();
  return false;
}

function pivotTable() {
    var elmTable = document.getElementsByClassName('tinderbox')[0];

    /* Get the old rows and figure out max cell count. */
    var aOldRows = [elmTable.rows.length]
    var cNewRows = 0;
    for (var i = 0; i < elmTable.rows.length; i++)
    {
        aOldRows[i] = elmTable.rows[i];
        var cCells = 0;
        for (var j = 0; j < aOldRows[i].cells.length; j++)
        {
            var cColSpan = aOldRows[i].cells[j].colSpan;
            cCells += cColSpan ? cColSpan : 1;
        }

        if (cCells > cNewRows)
            cNewRows = cCells;
    }

    /* Empty the table. */
    for (var i = elmTable.rows.length - 1; i >= 0; i--)
        elmTable.deleteRow(i);

    /* Insert new rows (empty). */
    var aNewRows = [cNewRows];
    var acSpans  = [cNewRows];
    for (var iNewRow = 0; iNewRow < cNewRows; iNewRow++)
    {
        aNewRows[iNewRow] = elmTable.insertRow(-1);
        acSpans[iNewRow]  = 1;
    }

    /* Do the pivot. */
    var oDateRegExp = new RegExp('[0-9][0-9]\/[0-9][0-9]\/[0-9][0-9] *');
    var sPrevDate = '';
    for (var i = 0; i < aOldRows.length; i++)
    {
        var aCells  = [aOldRows[i].cells.length];
        for (var j = 0; j < aOldRows[i].cells.length; j++)
            aCells[j] = aOldRows[i].cells[j];

        var iNewRow = -1;
        for (var j = 0; j < aCells.length; j++)
        {
            while (iNewRow + 1 < cNewRows)
            {
                iNewRow++;
                acSpans[iNewRow] -= 1;
                if (acSpans[iNewRow] <= 0)
                    break;
            }

            var elmCell  = aCells[j];
            var cColSpan = elmCell.colSpan;
            var cRowSpan = elmCell.rowSpan;
            elmCell.colSpan  = cRowSpan;
            elmCell.rowSpan  = cColSpan;
            if (iNewRow != 0)
                elmCell.noWrap = true;

            elmCell.childNodes.forEach(function(elm)
            {
                if (elm.nodeName == 'BR')
                    elmCell.replaceChild(document.createTextNode(' '), elm);
                else if (elm.nodeName == '#text')
                {
                    if (iNewRow == 0) /* truncate the date+time. */
                    {
                        var asMatches = elm.nodeValue.match(oDateRegExp);
                        if (asMatches)
                        {
                            sMatch = asMatches[0].trim();
                            if (sMatch == sPrevDate)
                                elm.nodeValue = elm.nodeValue.replace(oDateRegExp,'');
                            else
                            {
                                sPrevDate = sMatch;
                                elm.nodeValue = elm.nodeValue.replace(/ /g,'\u00A0');
                            }
                        }
                    }
                    else
                    {
                        elm.nodeValue = elm.nodeValue.replace(/warnings: 0/g,'');
                        elm.nodeValue = elm.nodeValue.replace(/warnings: /g,'w:');
                        elm.nodeValue = elm.nodeValue.replace(/\[/g,'');
                        elm.nodeValue = elm.nodeValue.replace(/]/g,'');
                    }
                    elm.nodeValue = elm.nodeValue.replace(/  */g, '\u00A0');
                }
                else if (elm.nodeName == 'B')
                {
                    if (elm.innerText == 'Time:')
                        elmCell.removeChild(elm);
                    else if (elm.innerText == 'Status:')
                    {
                        var elmNext = elm.nextSibling;
                        elmCell.removeChild(elm);

                        /* No need to show the 304 status. */
                        if (elmNext && elmNext.nodeName == '#text')
                        {
                            elmNext.nodeValue = elmNext.nodeValue.trim();
                            if (elmNext.nodeValue == '304')
                                elmCell.removeChild(elmNext);
                        }
                    }
                }
                else if (elm.nodeName == 'A')
                {
                    if (elm.innerHTML == 'raw_zip' && elm.href.endsWith('tar.gz'))
                        elm.innerHTML = 'tgz';
                    else if (elm.innerHTML.startsWith('build_'))
                        elm.innerHTML = elm.innerHTML.substr(6);
                    else if (elm.innerHTML == 'debug_rpm')
                        elm.innerHTML = 'dbgrpm';
                    else if (elm.innerHTML == 'efi_fw')
                        elm.innerHTML = 'efi';
                    else if (elm.innerHTML.endsWith('_zip'))
                        elm.innerHTML = elm.innerHTML.substr(0, elm.innerHTML.length - 4);
                    else if (elm.innerHTML == 'L')
                    {
                        elm.onclick = null;
                        /* Link to raw log */
                        var elmRawAnchor = document.createElement('A');
                        elmRawAnchor.href = elm.href + '&format=raw';
                        elmRawAnchor.innerHTML = 'R';
                        elmCell.insertBefore(elmRawAnchor, elm.nextSibling);
                    }
                }
            });
            elmCell.style.padding = '1px';
            if (i == 0)
            {
                elmCell.style.textAlign = 'right';
                elmCell.style.paddingRight  = '0.5em';
            }

            aNewRows[iNewRow].appendChild(elmCell);
            acSpans[iNewRow] = cRowSpan && cRowSpan > 0 ? cRowSpan : 1;
        }

        while (iNewRow + 1 < cNewRows)
        {
            iNewRow++;
            acSpans[iNewRow] -= 1;
        }
    }
}

function checkForPivot()
{
    var urlLocation    = new URL(location.href);
    var sPivotArg      = urlLocation.searchParams.get('pivot');
    var fPivot         = sPivotArg && sPivotArg != '0';
    if (fPivot)
        pivotTable();
    var elmPivotAnchor = document.getElementById('pivot-ref');
    if (elmPivotAnchor)
    {
        urlLocation.searchParams.set('pivot', fPivot ? '0' : '1')
        elmPivotAnchor.href = urlLocation.toString();
    }
}

</script>
</head>
<body onload="checkForPivot()">
<table WIDTH="100%" BORDER=0 CELLPADDING=0 CELLSPACING=0 onclick="closepopup()">
<tr><td>

<table id=tree_top><tr>
<td><span>Tinderbox: #TREE#</span> (#TIME#)<br>(<a href='sheriff.pl?tree=#TREE#'>Sheriff</a> | <a href='admintree.pl?tree=#TREE#'>Edit</a>)</td>
<td><a HREF="http://www.mozilla.org/"><img SRC="http://www.mozilla.org/images/mozilla-banner.gif" ALT="" BORDER=0 WIDTH=600 HEIGHT=58></a></td>
</tr></table>

<div id="popup" style="display: none" onclick="event.preventBubble()">
</div>

<table id="info_table">
<tr><td>
<table id="tree_info">
<tr><td colspan=2 id=tree_status>The tree is <span>#STATUS#</span></td></tr>
<tr><th>Sheriff:</th><td>#SHERIFF#</td></tr>
<tr><th>Build Engineer:</th><td>#BUILD_ENGINEER#</td></tr>
<tr><th>CVS pull:</th><td>#CVS_CO_DATE#</td></tr>
<tr><th>Patches:</th><td colspan=3>#PATCHES#</td></tr>
</table>
</td>
<td>
<p id="checkin_info"><strong>Tree Rules: <font color=red>Do not check in on red.</font></strong> Do not checkin without <a href="http://www.mozilla.org/hacking/reviewers.html">r=/sr= and a=</a>. Watch this Tinderbox after checkin to ensure all platforms compile and run.<br>
<strong>Checkin Comments:</strong> When you check in, be sure to include the bug number, who gave you r=/sr=/a=, and a clear description of what you did.</p>
</td>
</tr>
</table>

<div>
<a href='showbuilds.pl?tree=#TREE#&start_time=#START_TIME_MINUS(86400)#'>previous (earlier) period</a> - <a href='showbuilds.pl?tree=#TREE#&start_time=#END_TIME#'>next (later) period</a> - <a href='showbuilds.pl?tree=#TREE#'>current period</a><br>
^;

our $footer = q^<a href='showbuilds.pl?tree=#TREE#&start_time=#START_TIME_MINUS(86400)#'>previous (earlier) period</a> - <a href='showbuilds.pl?tree=#TREE#&start_time=#END_TIME#'>next (later) period</a> - <a href='showbuilds.pl?tree=#TREE#'>current period</a>
</div>
<address>Tinderbox 3: code problems to <a href='mailto:jkeiser@netscape.com'>John Keiser</a>, server problems to <a href='mailto:endico@mozilla.org'>Dawn Endico</a></address>
</td></tr></table>
</body>
</html>^;

our $sheriff = q^<a href='mailto:bird@innotek.de'>Bird</a>, IRC: <a href='irc://irc.netlabs.org/#netlabs'>BirdWrk</a>^;
our $build_engineer = q^<a href='mailto:bird@innotek.de'>Bird</a>, IRC: <a href='irc://irc.netlabs.org/#netlabs'>BirdWrk^;
our $special_message = q^^;

our $status = "open";

#
# bonsai defaults
#
our $display_name = "InnoTek checkins";
our $bonsai_url = "http://tindertux.intra-innotek.de/bonsai";
our $module = "VBox";
our $branch = "HEAD";
our $directory = "";
our $cvsroot = "/cvsroot";


1
