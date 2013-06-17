var infoTableRows = [
    'edition',
    'format',
    'type',
    'audience',
    'platforms',
    ['min_players', 'min. players'],
    ['max_players', 'max. players'],
    'minutes',
    'pages',
    'publishers',
    'actors',
    'languages',
    'features',
    'genres',
    'published',
    'purchased',
    ['serial', 'serial no.'],
    'isbn',
    'ean'
];

function write_info_table_divs() {
    var $table = $('#info-table');
    $table.html('<table cellpadding="0" cellspacing="0" border="0">');
    for (i in infoTableRows) {
        var n = infoTableRows[i];
        var v;
        if (typeof(n) == 'object') {
            v = n[1];
            n = n[0];
        }
        else {
            v = n;
        }
        $table.append('<tr id="info-table-' + n + '">' +
            '<td class="info-table-head">' + v + '</td>' +
            '<td class="info-table-data"></td>' +
            '</tr>'
        );
        infoTableRows[i] = n; // not idempotent!
    }
}

function window_size() {
    var height = window.innerHeight - 20;
    $('#info').css('height', height + 'px');
    $('#library').css('height', height + 'px');
}

function audience(str) {
    return(
        str == 'E'    ? 'Everyone' :
        str == 'E10+' ? 'Everyone 10+' :
        str == 'T'    ? 'Teen' :
        str == 'M'    ? 'Mature' :
        str
    )
}

function platform(str) {
    return(
        str == 'PS'   ? 'PlayStation' :
        str == 'PS2'  ? 'PlayStation 2' :
        str == 'PS3'  ? 'PlayStation 3' :
        str == 'PS4'  ? 'PlayStation 4' :
        str == 'PSP'  ? 'PlayStation Portable' :
        str == 'PSV'  ? 'PlayStation Vita' :
        str == 'Wii'  ? 'Nintendo Wii' :
        str == 'DS'   ? 'Nintendo DS' :
        str
    )
}

function info_table_row(d, name) {
    var name2;
    if (d[name] && typeof(d[name]) == 'object') { // post-process the audience/platform?
        var arr;
        if (name == 'platforms') {
            arr = [];
            for (var x in d[name])
                arr.push(platform(d[name][x]));
        }
        else
            arr = d[name];
        name2 = arr.join("<br>");
    }
    else {
        if (name == 'audience')
            name2 = audience(d[name]);
        else
            name2 = d[name];
    }

    var $id = $('#info-table-' + name + ' .info-table-data');
    if (name2) {
        $id.html(name2).parent().show();
    }
    else {
        $id.parent().hide();
    }
}

function info_html(id) {
    var d = libraryHash[id];

    $('#info-img').html('<img id="info-' + id + '-a" src="images/' + id + '.jpg">').show();
    if (d.url)
        $('#info-title').html('<a href="' + d.url +'" target="_blank">' + d.title + '</a>');
    else
        $('#info-title').html(d.title);

    $('#info-subtitle').html(d.creators.join('<br>'));

    for (var i in infoTableRows)
        info_table_row(d, infoTableRows[i]);

    if (d.desc)
        $('#info-desc').html(d.desc).show();
    else
        $('#info-desc').hide();
}

$(document).ready(function() {
    $('#library').html( '<table cellpadding="0" cellspacing="0" border="0" class="display" id="libraryTable"></table>' );
    $('#libraryTable').dataTable( {
        "aaData": libraryArray,
        "aaSorting": [[2,'asc']],
        "aLengthMenu": [[10, 25, 100, -1], [10, 25, 100, "All"]],
        "iDisplayLength": 10,
        "aoColumns": [
            { "sTitle": "PrimaryKey", "bSortable": false, "bSearchable": false, "bVisible": false },
            { "bSearchable": false, "bSortable": false },
            { "sTitle": "Title" },
            { "sTitle": "Audience" },
            { "sTitle": "Platforms" },
            { "sTitle": "Type" },
            { "sTitle": "Data", "bSortable": false, "bVisible": false }
        ],
        "sDom": 'W<"clear">lfrtipS',
        "bDeferRender": true,
        "oColumnFilterWidgets": {
            "aiExclude": [ 0, 1, 2, 6 ],
            //"sSeparator": "\\s*,\\s*",
            //"bGroupTerms": true
        },
        "fnDrawCallback": function( oSettings ) {
            $('.show-info').unbind().click(
                function() {
                    var id = $(this).parent().parent().first().first().html().match(/\d+/);
                    if (id) {
                        info_html(id);
                        $('#info').animate({scrollTop: 0}, 0);

                    }
                }
            );
        }
    } );

    write_info_table_divs();
    window_size();
    $(window).resize(function() {
        window_size();
    });

    $('.column-filter-widget:last select').val('VideoGame').change();
    $('.column-filter-widget:nth-child(2) select').val('PS3').change();
    $('.column-filter-widget:first select').val('E').change();
    $('.column-filter-widget:first select').val('E10+').change();
} );
