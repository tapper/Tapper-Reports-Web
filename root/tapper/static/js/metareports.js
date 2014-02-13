function get_chart_points ( $act_chart, params ) {

    var chart_id = $act_chart.closest('div.chart_boxs').attr('chart');
    if ( chart_id ) {

        var request_parameter = {};
        if ( params.parameter ) {
            request_parameter                   = params.parameter
        }

        request_parameter.json              = 1;
        request_parameter.chart             = chart_id;
        request_parameter.graph_width       = $act_chart.width();
        request_parameter.pager_direction   = $('#hd_pager_direction_idx').val();
        request_parameter.offset            = $('#hd_offset_idx').val();
        request_parameter.chart_tiny_url_id = $('#hd_chart_tiny_url_idx').val();

        $.ajax({
            method   : 'GET',
            dataType : 'json',
            url      : '/tapper/metareports/get_chart_points',
            data     : request_parameter,
            error    : function () {
                $act_chart.html('<span class="chart_error">unknown error occured</span>');
                return 0;
            },
            success  : function ( chart_data ) {

                var notification;
                var overview_identifier = "#overviewchart_" + chart_id;

                if ( chart_data.error ) {
                    notification = '<span class="chart_error">'+chart_data.error+'</span>';
                }
                else if ( chart_data.series.length < 1 ) {
                    notification = '<span class="chart_info">no data found</span>';
                }
                if ( notification ) {
                    $act_chart.html(notification);
                    if ( params.detail ) {
                        $(overview_identifier).html('');
                    }
                    return 0;
                }

                var options = {
                    points      : { show        : true },
                    xaxis       : { show        : true },
                    yaxis       : { show        : true },
                    selection   : { mode        : "xy" },
                    grid        : { borderWidth : 1 }
                };
                var options_overview = {
                    legend      : { show: false },
                    xaxis       : { show: false },
                    yaxis       : { show: false },
                    selection   : { mode: "xy" },
                    grid        : { borderWidth: 1 }
                };

                if ( chart_data.chart_type == 'points' ) {
                    options_overview.points = { show: true };
                }
                else if ( chart_data.chart_type == 'lines' ) {
                    if (! params.detail ) {
                        options.points.show = false;
                    }
                    options.lines          = { show: true };
                    options_overview.lines = { show: true };
                }

                if ( params.detail ) {
                    options.xaxis.ticks = Math.floor( $act_chart.width() / 22 );
                    options.grid        = {
                        hoverable: true,
                        clickable: true
                    };
                    if ( chart_data.order_by_x_axis == 1 && chart_data.order_by_y_axis == 2 ) {
                        options.yaxis.show  = false;
                    }
                    else if ( chart_data.order_by_x_axis == 2 && chart_data.order_by_y_axis == 1 ) {
                        options.xaxis.show  = false;
                    }
                }
                else {
                    options.xaxis.show  = false;
                    options.yaxis.show  = false;
                }

                var x_axis_labels    = [];
                var y_axis_labels    = [];
                var chart_identifier = "#mainchart_" + chart_id;

                if ( chart_data.xaxis_type == 'date' ) {
                    options.xaxis.mode       = "time";
                    options.xaxis.timeformat = "%Y-%m-%d %H:%M:%S";
                }
                if ( chart_data.yaxis_type == 'date' ) {
                    options.yaxis.mode       = "time";
                    options.yaxis.timeformat = "%Y-%m-%d %H:%M:%S";
                }

                if ( chart_data.xaxis_alphas.length > 0 ) {
                    options.xaxis.ticks = chart_data.xaxis_alphas;
                }
                if ( chart_data.yaxis_alphas.length > 0 ) {
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
                            if ( ( !x1 && !x2 ) || ( x1 < chart_data.series[i].data[j].x && chart_data.series[i].data[j].x < x2 ) ) {
                                line.data.push([
                                    chart_data.series[i].data[j].x,
                                    chart_data.series[i].data[j].y,
                                    chart_data.series[i].data[j]
                                ]);
                            }
                            if ( returner.min_x_value == undefined ) {
                                returner.min_x_value = chart_data.series[i].data[j].x;
                            }
                            else if ( chart_data.series[i].data[j].x_value < returner.min_x_value ) {
                                returner.min_x_value = chart_data.series[i].data[j].x;
                            }
                            if ( returner.max_x_value == undefined ) {
                                returner.max_x_value = chart_data.series[i].data[j].x;
                            }
                            else if ( chart_data.series[i].data[j].x_value > returner.max_x_value ) {
                                returner.max_x_value = chart_data.series[i].data[j].x;
                            }
                        }
                        returner.chart.push(line);
                    }

                    return returner;

                }

                if ( params.detail ) {

                    var plot;
                    var serialized = getData();

                    // hard-code color indices to prevent them from shifting as
                    // lines are turned on/off
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
                                var width = 0;
                                $('div.xAxis > div.tickLabel').each(function(){
                                    var label = $('<font>' + $(this).text() + '</font>').appendTo("body");
                                    if ( width < label.width() ) {
                                        width = label.width();
                                    }
                                    label.remove();
                                });
                                $(identifier).css( 'height', $(identifier).height() + Math.floor(width/2) );
                            }

                            plot = $.plot( chart_identifier, data, options );

                            set_plot_height( chart_identifier );

                            var $overview = $.plot( overview_identifier, data, options_overview );

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
                                $overview.setSelection(ranges, true);

                            });

                            $(overview_identifier).bind("plotselected", function (event, ranges) {
                                plot.setSelection(ranges);
                            });

                            function showTooltip( x, y, data, id ) {

                                var contents  = "";
                                    contents += "y-value: "     + ( data.yo ) + "<br />";
                                    contents += "x-value: "     + ( data.xo ) + "<br />"
                                ;

                                $.each( data.additionals, function( key, val ) {
                                    var value = val[0];
                                    if ( val[1] != null ) {
                                        value = '<a href="' + val[1].replace(/\$value\$/g, value) + '">' + value + '</a>';
                                    }
                                    contents += key + ": " + value + "<br />";
                                });

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
                                    + '&amp;offset='
                                    + $('#hd_offset_idx').val()
                                ;
                                return url;
                            }

                            var max_series_length = 0;
                            for ( var i = 0; i < chart_data.series.length; i = i + 1 ) {
                                if ( chart_data.series[i].data.length > max_series_length ) {
                                    max_series_length = chart_data.series[i].data.length;
                                }
                            }
                            if ( Math.floor( $act_chart.width() / 4 ) == max_series_length ) {
                                $('#dv_searchleft_idx').click(function(){
                                    location.href = create_search_url() + '&amp;pager_direction=prev';
                                }).css('cursor','pointer');
                            }
                            if (
                                   $('#hd_offset_idx').val() != 0
                                && $('#hd_offset_idx').val() != ( 2 * chart_data.offset )
                            ) {
                                $('#dv_searchright_idx').click(function(){
                                    location.href = create_search_url() + '&amp;pager_direction=next';
                                }).css('cursor','pointer');
                            }
                            $('#hd_offset_idx').val( chart_data.offset );

                            $('#bt_create_static_url_idx').click(function(){
                                $(this)
                                    .attr('disabled','disabled')
                                    .val('Saving ...')
                                ;
                                var ids = [];
                                for ( var i = 0; i < chart_data.series.length; i = i + 1 ) {
                                    ids[i] = {
                                        data          : [],
                                        chart_line_id : chart_data.series[i].chart_line_id
                                    };
                                    for ( var j = 0; j < chart_data.series[i].data.length; j = j + 1 ) {
                                        ids[i].data[j] = chart_data.series[i].data[j].additionals.VALUE_ID[0];
                                    }
                                }
                                $.ajax({
                                    method   : 'POST',
                                    dataType : 'json',
                                    url      : '/tapper/metareports/create_static_url',
                                    data     : {
                                        'json'  : 1,
                                        'ids'   : $.toJSON( ids )
                                    },
                                    success  : function ( data ) {
                                        $('#bt_create_static_url_idx').replaceWith(
                                              '<a href="/tapper/metareports/detail?chart_tiny_url_id='
                                            + data.chart_tiny_url_id
                                            + '">'
                                            + 'Go to static URL'
                                            + '</a>'
                                        );
                                    }
                                });
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

            },
        });
    }
}
