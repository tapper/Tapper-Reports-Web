function get_chart_points ( $act_chart, detail ) {

    var options = {
        lines       : { show        : true },
        points      : { show        : true },
        xaxis       : { show        : true },
        yaxis       : { show        : true },
        selection   : { mode        : "xy" },
        grid        : { borderWidth : 1 }
    };
    var options_overview = {
        lines       : { show: true },
        points      : { show: false },
        legend      : { show: false },
        xaxis       : { show: false },
        yaxis       : { show: false },
        selection   : { mode: "xy" },
        grid        : { borderWidth: 1 }
    };

    if (! detail ) {
        options.points.show = false;
        options.xaxis.show  = false;
        options.yaxis.show  = false;
    }
    else {
        options.xaxis.ticks = Math.floor( $act_chart.width() / 22 );
        options.grid        = {
            hoverable: true,
            clickable: true
        };
    }

    var chart_id   = $act_chart.closest('div.chart_boxs').attr('chart');
    if ( chart_id ) {
        $.ajax({
            method   : 'GET',
            dataType : 'json',
            url      : '/tapper/metareports/get_chart_points',
            data     : {
                'json'              : 1,
                'chart'             : chart_id,
                'graph_width'       : $act_chart.width(),
                'left_of_value'     : $('#idx_left_of_value').val(),
                'right_of_value'    : $('#idx_right_of_value').val(),
                'searchfrom'        : $('#tx_searchfrom_idx').val(),
                'searchto'          : $('#tx_searchto_idx').val()
            },
            success  : function ( chart_data ) {

                var x_axis_labels    = [];
                var y_axis_labels    = [];
                var chart_identifier = "#mainchart_" + chart_id;

                if ( chart_data.series.length ) {
                    if ( chart_data.xaxis_type == 'date' ) {
                        options.xaxis.mode       = "time";
                        options.xaxis.timeformat = "%Y-%m-%d %H:%M:%S";
                    }
                    else if ( chart_data.xaxis_type == 'alphanumeric' ) {
                        options.xaxis.ticks = chart_data.xaxis_alphas;
                    }

                    if ( chart_data.yaxis_type == 'date' ) {
                        options.yaxis.mode       = "time";
                        options.yaxis.timeformat = "%Y-%m-%d %H:%M:%S";
                    }
                    else if ( chart_data.yaxis_type == 'alphanumeric' ) {
                        options.yaxis.ticks = chart_data.yaxis_alphas;
                    }

                    function getData( x1, x2 ) {

                        var returner = { chart : [] };

                        for ( var i = 0; i < chart_data.series.length; i++ ) {

                            var line = {
                                label : chart_data.series[i].label,
                                data  : []
                            };
                            for ( var j = 0; j < chart_data.series[i].data.length; j++ ) {
                                if ( ( !x1 && !x2 ) || ( x1 < chart_data.series[i].data[j].x_value && chart_data.series[i].data[j].x_value < x2 ) ) {
                                    line.data.push([
                                        chart_data.series[i].data[j].x_value,
                                        chart_data.series[i].data[j].y_value,
                                        chart_data.series[i].data[j]
                                    ]);
                                }
                                if ( returner.min_x_value == undefined ) {
                                    returner.min_x_value = chart_data.series[i].data[j].x_value;
                                }
                                else if ( chart_data.series[i].data[j].x_value < returner.min_x_value ) {
                                    returner.min_x_value = chart_data.series[i].data[j].x_value;
                                }
                                if ( returner.max_x_value == undefined ) {
                                    returner.max_x_value = chart_data.series[i].data[j].x_value;
                                }
                                else if ( chart_data.series[i].data[j].x_value > returner.max_x_value ) {
                                    returner.max_x_value = chart_data.series[i].data[j].x_value;
                                }
                            }
                            returner.chart.push(line);
                        }

                        return returner;

                    }

                    if ( detail ) {

                        var plot;
                        var serialized = getData();

                        // hard-code color indices to prevent them from shifting as
                        // countries are turned on/off
                        var i = 0;
                        $.each( serialized.chart, function( key, val ) {
                            val.color = i;
                            ++i;
                        });

                        // insert checkboxes
                        var choiceContainer = $("#choices");
                        $.each( serialized.chart, function( key, val ) {
                            choiceContainer.append(
                                '<br/><input type="checkbox" name="' + key +
                                '" checked="checked" id="id' + key + '">' +
                                '<label for="id' + key + '">' +
                                val.label + '</label>'
                            );
                        });

                        function plotAccordingToChoices() {
                            var data = [];
                            choiceContainer.find("input:checked").each(function () {
                                var key = $(this).attr("name");
                                if (key && serialized.chart[key])
                                    data.push(serialized.chart[key]);
                            });

                            if ( data.length > 0 ) {

                                function set_plot_height( identifier ) {
                                    // get width of text
                                    var width   = 0;
                                    $('div.xAxis > div.tickLabel').each(function(){
                                        var label = $('<font>' + $(this).text() + '</font>').appendTo("body");
                                        if ( width < label.width() ) {
                                            width = label.width();
                                        }
                                        label.remove();
                                    });
                                    $(identifier).css( 'height', $(identifier).height() + Math.floor(width/2) );
                                }

                                plot  = $.plot( chart_identifier, data, options );

                                set_plot_height( chart_identifier );

                                var overview_identifier = "#overviewchart_" + chart_id;
                                var overview            = $.plot( overview_identifier, data, options_overview );

                                $(chart_identifier).bind("plotselected", function (event, ranges) {

                                    // clamp the zooming to prevent eternal zoom
                                    if (ranges.xaxis.to - ranges.xaxis.from < 0.00001) {
                                        ranges.xaxis.to = ranges.xaxis.from + 0.00001;
                                    }
                                    if (ranges.yaxis.to - ranges.yaxis.from < 0.00001) {
                                        ranges.yaxis.to = ranges.yaxis.from + 0.00001;
                                    }

                                    // do the zooming
                                    var serialized = getData( ranges.xaxis.from, ranges.xaxis.to );
                                    plot = $.plot( chart_identifier, serialized.chart,
                                        $.extend(true, {}, options, {
                                            xaxis: { min: ranges.xaxis.from, max: ranges.xaxis.to },
                                            yaxis: { min: ranges.yaxis.from, max: ranges.yaxis.to }
                                        })
                                    );

                                    set_plot_height( chart_identifier );

                                    // don't fire event on the overview to prevent eternal loop
                                    overview.setSelection(ranges, true);

                                });

                                $(overview_identifier).bind("plotselected", function (event, ranges) {
                                    plot.setSelection(ranges);
                                });

                                function showTooltip( x, y, data, id ) {

                                    var contents  = "";
                                        contents += "y-value: "     + ( data.y_value_tmp || data.y_value ) + "<br />";
                                        contents += "x-value: "     + ( data.x_value_tmp || data.x_value ) + "<br />"
                                    ;

                                    for ( var i = 0; i < data.additionals.length; i++ ) {
                                        var value = data.additionals[i][1];
                                        if ( data.additionals[i][2] != null ) {
                                            value = '<a href="' + data.additionals[i][2].replace(/\$value\$/g, data.additionals[i][1]) + '">' + value + '</a>';
                                        }
                                        contents += data.additionals[i][0] + ": " + value + "<br />";
                                    }

                                    $('<div id="'+id+'">' + contents + '</div>').css( {
                                        position: 'absolute',
                                        display: 'none',
                                        top: y + 5,
                                        left: x + 5,
                                        border: '1px solid #fdd',
                                        padding: '2px',
                                        'background-color': '#fee',
                                        opacity: 0.80
                                    }).appendTo("body").fadeIn(200);

                                }

                                var previousPointHover = null;
                                $(chart_identifier).bind("plothover", function (event, pos, item) {
                                    if ( item ) {
                                        if ( previousPointHover != item.dataIndex ) {
                                            previousPointHover = item.dataIndex;
                                            $("#hovertip").remove();
                                            var x    = item.datapoint[0].toFixed(2),
                                                y    = item.datapoint[1].toFixed(2),
                                                data = item.series.data[item.dataIndex][2]
                                            ;
                                            showTooltip( item.pageX, item.pageY, data, 'hovertip' );
                                        }
                                    }
                                    else {
                                        $("#hovertip").remove();
                                        previousPointHover = null;
                                    }
                                });

                                var previousPointClick = null;
                                $(chart_identifier).bind("plotclick", function (event, pos, item) {
                                    if ( item ) {
                                        if ( previousPointClick != item.dataIndex ) {
                                            previousPointClick = item.dataIndex;
                                            $("#clicktip").remove();
                                            var x    = item.datapoint[0].toFixed(2),
                                                y    = item.datapoint[1].toFixed(2),
                                                data = item.series.data[item.dataIndex][2]
                                            ;
                                            showTooltip( item.pageX, item.pageY, data, 'clicktip' );
                                        }
                                    }
                                    else {
                                        $("#clicktip").remove();
                                        previousPointClick = null;
                                    }
                                });

                                function create_search_url(){
                                    var url =
                                          '/tapper/metareports/detail?owner_id='
                                        + $('#idx_owner').val()
                                        + '&amp;chart_id='
                                        + $act_chart.closest('div.chart_boxs').attr('chart')
                                        + '&amp;searchfrom='
                                        + $('#tx_searchfrom_idx').val()
                                        + '&amp;searchto='
                                        + $('#tx_searchto_idx').val()
                                    ;
                                    return url;
                                }

                                $('#dv_searchleft_idx').click(function(){
                                    location.href =
                                          create_search_url()
                                        + '&amp;left_of_value='
                                        + serialized.min_x_value
                                    ;
                                });
                                $('#dv_searchright_idx').click(function(){
                                    location.href =
                                          create_search_url()
                                        + '&amp;right_of_value='
                                        + serialized.max_x_value
                                    ;
                                });
                                $('#bt_search_idx').click(function(){
                                    location.href = create_search_url();
                                });

                                if ( chart_data.xaxis_type == 'date' ) {
                                    $.timepicker.regional['de'] = {
                                        timeOnlyTitle   : 'Select time',
                                        timeText        : 'Time',
                                        hourText        : 'Hour',
                                        minuteText      : 'Minute',
                                        secondText      : 'Second',
                                        currentText     : 'New',
                                        closeText       : 'Select',
                                        ampm            : false
                                    };
                                    $.timepicker.setDefaults($.timepicker.regional['de']);

                                    $('#tx_searchfrom_idx').datetimepicker({
                                        dateFormat: 'yy-mm-dd',
                                    });
                                    $('#tx_searchto_idx').datetimepicker({
                                        dateFormat: 'yy-mm-dd',
                                    });
                                }

                            }

                        }

                        choiceContainer.find("input").click( plotAccordingToChoices );

                        plotAccordingToChoices();

                   }
                    else {
                        var serialized = getData();
                        $.plot( chart_identifier, serialized.chart, options );
                        $act_chart.click(function(){
                            location.href = '/tapper/metareports/detail?owner_id='+$('#idx_owner').val()+'&amp;chart_id='+$(this).closest('div.chart_boxs').attr('chart');
                        });
                    }

                }
                else {
                    $act_chart.html('<span>no data found</span>');
                }

            },
        });
    }
}