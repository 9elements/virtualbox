
function closepopup()
{
  document.getElementById('popup').style.display = 'none';
}

function do_popup(event,_class,str)
{
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

/** Called by 'onclick' for the 'L' on the builds. */
function do_L_popup(oEvent, sTree, sMachineNm, idMachine, secBuildTime, sLogFile)
{
    var sHtml = '<b>' + sMachineNm + '</b><br>\n';
    var sAHref = "<a href='showlog.pl?machine_id=" + idMachine + "&logfile=" + sLogFile;
    sHtml += sAHref + "&format=raw'>Raw Log</a><br>\n";
    sHtml += sAHref + "'>Show Log</a><br>\n";
    sHtml += "<a href='buildcomment.pl?tree=" + sTree + "&machine_id=" + idMachine + "&build_time=" + secBuildTime + "'>";
    sHtml += "Add Comment</a>";
    return do_popup(event, "log", sHtml);
}

function toggle_check_boxes(elmCheckbox, _class)
{
    var aElements = document.getElementsByClassName(_class);
    var i;
    for (i = 0; i < aElements.length; i++)
    {
        aElements[i].checked = elmCheckbox.checked;
    }
    return true;
}

function urlRemoveParam(sUrl, sParam)
{
    var oUrl = new URL(sUrl);
    oUrl.searchParams.delete(sParam);
    return oUrl.href;
}

/**
 * Worker for group_action_combo_changed that handles the selection items.
 */
function group_action_combo_changed_selection(elmComboBox, sCriterion, fSelectAction)
{
    /*
     * Pre-perprocess the selection criterion.  The caller split out the action
     * part (select/unselect), so we're left with field and value.
     */
    var aSplit  = sCriterion.split("_", 2);
    var oRegExp = new RegExp(aSplit[0]+':\\s+'+aSplit[1]);

    /*
     * Do the work.
     */
    var aElements = document.getElementsByClassName("group_action_checkbox");
    var i;
    for (i = 0; i < aElements.length; i++)
    {
        var sTitle = aElements[i].title;
        if (sTitle && sTitle.match(oRegExp))
        {
            aElements[i].checked = fSelectAction;
        }
    }

    /*
     * Don't leave it selected!
     */
    elmComboBox.value = "";
    return true;
}

/** onchange handler for the group action combo box
 *  (see column_header_2 in BuildTimeColumn.pm). */
function group_action_combo_changed(elmComboBox, _class)
{
    var sValue = elmComboBox.value;
    if (!sValue)
        return false;

    /*
     * Deal with select/unselect "actions".
     */
    if (sValue.startsWith("select_"))
        return group_action_combo_changed_selection(elmComboBox, sValue.substr(7), true);
    if (sValue.startsWith("unselect_"))
        return group_action_combo_changed_selection(elmComboBox, sValue.substr(9), false);

    var oUrl = new URL(window.location.href);

    /*
     * Deal with actions not requiring any checkboxes.
     */
    if (sValue == 'view_all')
    {
        /* Just need to remove the exclude and include lists from the URL. */
        oUrl.searchParams.delete('hide');
        oUrl.searchParams.delete('show');
        window.location.assign(oUrl.href);
        elmComboBox.value = "";
        return true;
    }

    /*
     * Collect checkbox states.
     */
    var aidChecked    = new Array();
    var aidNotChecked = new Array();
    var aElements     = document.getElementsByClassName(_class);
    var i;
    for (i = 0; i < aElements.length; i++)
    {
        if (aElements[i].checked)
            aidChecked.push(aElements[i].value);
        else
            aidNotChecked.push(aElements[i].value);
    }

    /*
     * If static page we need to figure out the style and tree from the page name.
     */
    var fStatic = oUrl.pathname.endsWith('.html');
    if (fStatic)
    {
        var oRegExp = /\/([^/]+)\.html$/;
        var sTree  = oRegExp.exec(oUrl.pathname)[1];
        var sStyle = '';
        if (sTree.endsWith('-brief'))
            sStyle = 'brief';
        else if (sTree.endsWith('-pivot'))
            sStyle = 'pivot';

        if (sStyle.length > 0)
        {
            oUrl.searchParams.set('style', sStyle);
            sTree = sTree.substr(0, sTree.length - sStyle.length - 1);
        }
        oUrl.searchParams.set('tree', sTree);
    }

    /*
     * View/filtering.
     */
    if (sValue.startsWith('view_'))
    {
        if (fStatic)
            oUrl.pathname = oUrl.pathname.replace(/\/[^/]+$/, 'showbuilds.pl');

        /* Only view the selected IDs.  Do nothing if nothing was selected. */
        if (sValue == 'view_only' && aidChecked.length >= 1)
        {
            oUrl.searchParams.delete('hide');
            oUrl.searchParams.set('show', aidChecked.join(','));
            window.location.assign(oUrl.href);
        }
        /* Hide the selected machines. Do nothing if nothing was selected. */
        else if (sValue == 'view_omit' && aidChecked.length >= 1)
        {
            oUrl.searchParams.append('hide', aidChecked.join(','));
            window.location.assign(oUrl.href);
        }
    }
    /*
     * Take machine action.
     */
    else if (aidChecked.length < 1)
        alert("No machines checked!");
    else
    {
        oUrl.searchParams.set('action', sValue);
        oUrl.searchParams.set('action_ids', aidChecked.join(','));
        oUrl.pathname = oUrl.pathname.replace(/\/[^/]+$/, 'showbuildsaction.pl');
        window.location.assign(oUrl.href);
    }

    elmComboBox.value = ""; /* Don't leave it selected in case the user goes back. */
    return true;
}

/* Integrated into the style stuff. */
function checkForPivot()
{
}

