
import 'dart:ffi';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:get/get.dart';

class ChartComponent extends StatelessWidget {
  final int maxHistoryLength;
  final String xAxis;
  /*
  history = [
  {
  [metricName]: [metricValue],
  },
  ...
  ]
   */
  final List<dynamic> history;
  /*
  spec = {
	"viewType": "Run History Line Plot", // only this type will be supported for now
	"config": {
		"metrics":
		[
			"max_pos",
			"positive_acc",
			"negative_acc",
			"max_neg"
		],

		"useMetricRegex": false,
		"yLogScale": false, //
		"xLogScale": false, //
		"smoothingWeight":  number or float or 0,
		"smoothingType": "exponentialTimeWeighted" || "movingAverage" || "gaussian" || "none"
		"useGlobalSmoothingWeight": false,
		"showOriginalAfterSmoothing": false,// show original data after smoothing

		"useLocalSmoothing": false,
		"overrideColors": {
			"max_pos": {
				"color": "rgb(71, 154, 95)",
				"transparentColor": "rgba(71, 154, 95, 0.1)"
			},
			"positive_acc": {
				"color": "rgb(34, 148, 135)",
				"transparentColor": "rgba(34, 148, 135, 0.1)"
			},
			"negative_acc": {
				"color": "rgb(218, 76, 76)",
				"transparentColor": "rgba(218, 76, 76, 0.1)"
			},
			"max_neg": {
				"color": "rgb(161, 40, 100)",
				"transparentColor": "rgba(161, 40, 100, 0.1)"
			}
		}
		"overrideMarks" :{"max_pos":"dotted","min_pos":"solid","min_neg":"dotted","max_neg":"solid"}
	},
}
   */
  final dynamic spec;
  static String _formatLargeNumber(num? value) {
    if (value == null) {
      return "";
    }
    if (value == 0) {
      return "0";
    }
    if (value >= 1000000000) {
      return (value / 1000000000).toStringAsFixed(1) + 'b';
    } else if (value >= 1000000) {
      return (value / 1000000).toStringAsFixed(1) + 'm';
    } else if (value >= 1000) {
      return (value / 1000).toStringAsFixed(1) + 'k';
    } else {
      return value.toString();
    }
  }
  final Function onPressed;

  const ChartComponent({super.key,required this.history,
    required this.spec,
    this.maxHistoryLength=400,
    required this.xAxis, required this.onPressed
  });
  Map<String, num> _findAxisBoundsWithMargin(slicedHistory) {
    num maxValue = 0;
    num minValue = double.infinity;
    for (var row in slicedHistory) {
      var sortedAndDeuplicatedKeys = spec["config"]["metrics"]
          .toSet().toList()
          .map(( metric ) => metric.replaceAll("system/","system."));
      for (var metric in sortedAndDeuplicatedKeys) {
        maxValue = max(maxValue, row[metric]??maxValue);
        minValue = min(minValue, row[metric]??minValue);
      }
    }

    // if minvalue is more than maxvalue, set minvalue to 0
    if(minValue > maxValue){
      minValue = 0;
    }
    // Adding a margin of 10%
    num margin = maxValue * 0.2;
    maxValue += margin;
    minValue = minValue > 0 ? (minValue - (minValue * 0.2)) : minValue;

    return {"max": maxValue, "min": minValue};
  }
  Map<String, num> _findDomainAxisBoundsWithMargin(List<dynamic> slicedHistory) {
    num maxValue = 0;
    num minValue = double.infinity;

    for (var row in slicedHistory) {
      var value = row[xAxis] ?? row["_runtime"];  // Replace with the actual logic to get the X-axis value from row
      maxValue = max(maxValue, value);
      minValue = min(minValue, value);
    }

    num margin = (maxValue - minValue) * 0.1;  // 10% margin
    maxValue += margin;
    minValue -= margin;

    return {"max": maxValue, "min": minValue};
  }

  List<charts.Series<dynamic, num>> _createSeriesList(List slicedHistory) {
    List<charts.Series<dynamic, num>> seriesList = [];
    var sortedAndDeuplicatedKeys = spec["config"]["metrics"]
        .toSet().toList()
        .map(( metric ) => metric.replaceAll("system/","system."));
    for (var metric in sortedAndDeuplicatedKeys) {
      var series = charts.Series<dynamic, num>(
        id: metric,
        colorFn: (_, __) => _getColorForMetric(metric), // Implement this method
        domainFn: (dynamic row, _) => row[xAxis] ?? row["_runtime"],       // Assuming xAxis is correctly set
        measureFn: (dynamic row, _) => row[metric],     // Ensure 'metric' is a key in your data
        data: slicedHistory,                       // Make sure this is structured correctly
      );
      seriesList.add(series);
    }

    return seriesList;
  }
  charts.Color _getColorForMetric(String metric) {
    // Replace with your logic to get the color based on 'spec'
    var colorFromSpec = spec["config"]?["overrideColors"]?[metric]?["color"];
    if (colorFromSpec != null) {
      if(colorFromSpec is String){
        if(colorFromSpec.startsWith("#")){
          return charts.Color.fromHex(code: colorFromSpec);
        } else if (colorFromSpec.startsWith("rgb")){
          var rgb = colorFromSpec.substring(4, colorFromSpec.length-1).split(",");
          return charts.Color(r: int.parse(rgb[0]), g: int.parse(rgb[1]), b: int.parse(rgb[2]));
        }
      }

    }
    // random color from the list
    var colorsList = [
      charts.MaterialPalette.blue.shadeDefault,
      charts.MaterialPalette.red.shadeDefault,
      charts.MaterialPalette.green.shadeDefault,
      charts.MaterialPalette.yellow.shadeDefault,
      charts.MaterialPalette.purple.shadeDefault,
      charts.MaterialPalette.cyan.shadeDefault,
      charts.MaterialPalette.deepOrange.shadeDefault,
      charts.MaterialPalette.indigo.shadeDefault,
      charts.MaterialPalette.lime.shadeDefault,
      charts.MaterialPalette.pink.shadeDefault,
      charts.MaterialPalette.teal.shadeDefault,
      charts.MaterialPalette.cyan.shadeDefault,
      charts.MaterialPalette.deepOrange.shadeDefault,
      charts.MaterialPalette.green.shadeDefault,
      charts.MaterialPalette.indigo.shadeDefault,
      charts.MaterialPalette.lime.shadeDefault,
      charts.MaterialPalette.pink.shadeDefault,
      charts.MaterialPalette.purple.shadeDefault,
      charts.MaterialPalette.red.shadeDefault,
      charts.MaterialPalette.teal.shadeDefault,
      charts.MaterialPalette.yellow.shadeDefault,
    ];

    // get random color from the list
    return colorsList[metric.hashCode % colorsList.length];

  }

  List<charts.ChartTitle<num>> _createChartTitles() {
    return spec["config"]["metrics"].map<charts.ChartTitle<num>>((metric) {
      return charts.ChartTitle<num>(
          metric,
          behaviorPosition: charts.BehaviorPosition.start,
          titleOutsideJustification: charts.OutsideJustification.middleDrawArea
      );
    }).toList();
  }
  @override
  Widget build(BuildContext context) {
    // Determine the start index for slicing the history data
    int startIndex = history.length > maxHistoryLength ? history.length - maxHistoryLength : 0;
    // Slice the history to only include the last maxHistoryLength entries
    List<dynamic> slicedHistory = history.sublist(startIndex);
    var bounds = _findAxisBoundsWithMargin(slicedHistory);
    var xbounds = _findDomainAxisBoundsWithMargin(slicedHistory);
    // TODO: implement build
    if(spec.containsKey("viewType") && spec["viewType"] == "Run History Line Plot"){
      return  Container(
        width: double.infinity,

        constraints: BoxConstraints(
          maxHeight: 300,
        ),
        child: charts.LineChart(

          // [
          //  ...[for (var metric in this.spec["config"]["metrics"]) {
          //     charts.Series<dynamic, num>(
          //       id: spec["__id__"],
          //       colorFn: (dynamic item, __) => charts.MaterialPalette.blue.shadeDefault,
          //       domainFn: (dynamic item, _) => item[this.xAxis],
          //       measureFn: (dynamic item, _) {
          //         return item[metric];
          //       },
          //       data: history,
          //     )
          //   }][0].toList()
          // ],
          _createSeriesList(slicedHistory),
          animate: true,
          defaultRenderer: charts.LineRendererConfig(includeArea: false,
              stacked: false,
          strokeWidthPx: 0.9
          ),
          primaryMeasureAxis: charts.NumericAxisSpec(
            tickFormatterSpec: charts.BasicNumericTickFormatterSpec(_formatLargeNumber),
            viewport: charts.NumericExtents(bounds["min"] ?? 0, bounds["max"] ?? 1),

          ),
          domainAxis: charts.NumericAxisSpec(
            tickFormatterSpec: charts.BasicNumericTickFormatterSpec(_formatLargeNumber),
            viewport: charts.NumericExtents(xbounds["min"] ?? 0, xbounds["max"] ?? 1),

            //logScale: spec["config"]["xLogScale"] ?? false,
          ),
          behaviors: [
            charts.ChartTitle(this.xAxis,
                titleStyleSpec: charts.TextStyleSpec(fontSize: 12),
                behaviorPosition: charts.BehaviorPosition.bottom,
                titleOutsideJustification: charts.OutsideJustification.middleDrawArea),
           // charts.ChartTitle(
           //     spec["config"]["metrics"].join(", "),
           //     titleStyleSpec: charts.TextStyleSpec(fontSize: 10),
           // ),
            charts.SeriesLegend(
              position: charts.BehaviorPosition.top,
              horizontalFirst: false,
              desiredMaxRows: 2,
              cellPadding: EdgeInsets.only(right: 4.0, bottom: 4.0),
              entryTextStyle: charts.TextStyleSpec(
                  color: charts.MaterialPalette.black,
                  fontSize: 10),
            ),
            charts.PanAndZoomBehavior(),
            charts.SelectNearest(

            ),
            charts.DomainHighlighter(),
            charts.LinePointHighlighter(
                showHorizontalFollowLine:
                charts.LinePointHighlighterFollowLineType.nearest,
                showVerticalFollowLine:
                charts.LinePointHighlighterFollowLineType.nearest
            ),
          ],
          selectionModels: [
            charts.SelectionModelConfig(
              type: charts.SelectionModelType.info,
              changedListener: (charts.SelectionModel model) {
                this.onPressed();
              },
            )
          ],
        ),
      );
    }else{
      return Container(

      );
    }
  }

}