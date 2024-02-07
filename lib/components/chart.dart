import 'dart:async';

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' as material;
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wandview/utils/utilities.dart';

import '../utils/controllers.dart';

List<Point> applyGaussianSmoothing(List<Point> inputSeries,
    {double sigma = 2.0, int kernelSize = 2}) {
  //return inputSeries;
  // Adjusted default values
  // Ensure kernel size is odd
  if (kernelSize % 2 == 0) {
    kernelSize += 1;
  }

  // Generate Gaussian kernel
  List<double> kernel = List.filled(kernelSize, 0);
  int mid = kernelSize ~/ 2;
  double sum = 0.0;

  for (int i = 0; i < kernelSize; i++) {
    kernel[i] = exp(-0.5 * pow((i - mid) / sigma, 2));
    sum += kernel[i];
  }

  // Normalize the kernel
  for (int i = 0; i < kernelSize; i++) {
    kernel[i] /= sum;
  }

  // Apply Gaussian smoothing only to y values
  List<Point> smoothedSeries = [];
  for (int i = 0; i < inputSeries.length; i++) {
    double smoothedY = 0.0;

    for (int j = 0; j < kernelSize; j++) {
      int index = i - mid + j;
      if (index >= 0 && index < inputSeries.length) {
        smoothedY += inputSeries[index].y * kernel[j];
      }
    }

    smoothedSeries
        .add(Point(inputSeries[i].x, smoothedY)); // Keep x value unchanged
  }

  return smoothedSeries;
}

class ChartComponent extends StatefulWidget {
  final int maxHistoryLength;
  final String xAxis;

  final dynamic spec;
  final RxList<Map<String, dynamic>> historyWatchable;
  final Function onPressed;
  final Function lastValuesReport;
  final bool isBordered;
  final String runName;

  ChartComponent(
      {super.key,
      this.maxHistoryLength = 600,
      this.isBordered = false,
      required this.xAxis,
      required this.spec,
      required this.runName,
      required this.historyWatchable,
      required this.onPressed,
      required this.lastValuesReport});

  @override
  _ChartComponentState createState() => _ChartComponentState();
}

class _ChartComponentState extends State<ChartComponent>
    with AutomaticKeepAliveClientMixin {
  late StreamSubscription historyWatchableStream;
  var history = List<Map<String, dynamic>>.empty(growable: true);
  var disposed = false;
  var bounds = {};
  var xbounds = {};
  var slicedHistory = List<dynamic>.empty(growable: true);
  var isLoaded = true;
  double? get  lastSeenDomain {
    var appSessionId = prefs.getString("appSession")!;
    var runName = widget.runName;
    return prefs.getDouble("$appSessionId:$runName:lastSeenStep");
  }
  late SharedPreferences prefs;

  void loadUp(List<Map<String, dynamic>> _history, {setToState = true}) {
    int startIndex = _history.length > widget.maxHistoryLength
        ? _history.length - widget.maxHistoryLength
        : 0;
    // Slice the history to only include the last maxHistoryLength entries
    //check if widget is mounted  and not locked
    if (!this.mounted || disposed) {
      return;
    }
    if (setToState) {
      WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {
            slicedHistory = _history;
            bounds = _findAxisBoundsWithMargin(slicedHistory);
            xbounds = _findDomainAxisBoundsWithMargin(slicedHistory);
            history = _history;
          }));
    } else {
      slicedHistory = _history;
      bounds = _findAxisBoundsWithMargin(slicedHistory);
      xbounds = _findDomainAxisBoundsWithMargin(slicedHistory);
      history = _history;
    }
  }

  @override
  void deactivate() {
    // TODO: implement deactivate
    //  historyWatchableStream.pause();
    super.deactivate();
  }

  @override
  void activate() {
    // historyWatchableStream.resume();
    // TODO: implement activate
    super.activate();
  }

  @override
  void initState() {
    // TODO: implement initState

    SharedPreferences.getInstance().then((_prefs) {
      prefs= _prefs;
      loadUp(widget.historyWatchable.value.toList(), setToState: true);
      historyWatchableStream = widget.historyWatchable.stream.listen((val) {
        if (disposed) {
          return;
        }

        if (this.mounted) {
          loadUp(val, setToState: true);
          // var applied =  applyLogarithmicScale(gaussianSmoothListMap(scaleDownByDomain((val ))));
          // loadUp(applied);
        }

        // try{
        //
        // }catch(e){
        //   throw e;
        // }
      }, onError: (e) {
        throw e;
      });
    });

    super.initState();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    disposed = true;
    historyWatchableStream.cancel();
    super.dispose();
  }

  String _formatLargeNumber(num? value) {
    if (value == null) {
      return "";
    }
    if (value == 0) {
      return "0";
    }
    value = exp(value);
    value -= 1;
    if (value == 0) {
      return "0";
    }
    var fractionalPart = value.toString().split(".")?[1];

    if (value >= 1000000000) {
      return (value / 1000000000).toStringAsFixed(1) + 'B';
    } else if (value >= 1000000) {
      return (value / 1000000).toStringAsFixed(1) + 'M';
    } else if (value >= 1000) {
      return (value / 1000).toStringAsFixed(1) + 'K';
    } else if (value.toString().split(".").length == 1) {
      return value.toString();
    } else if (value >= 100) {
      return (value).toStringAsFixed(2);
    } else if (value > 1 &&
        fractionalPart != null &&
        fractionalPart.length <= 4) {
      return value.toString();
    } else if (value < 1) {
      return value.toStringAsPrecision(2);
    }
    return value.floor().toString();
  }

  String _formatDomainAxis(num? value) {
    if (value == null) {
      return "";
    }
    // value -= 5;
    if (value <= 0) {
      return value.floor().toString();
    }

    var logValue = deExpIt(value);
    return logValue.floor().toString();
  }

  Map<String, num> _findAxisBoundsWithMargin(List slicedHistory) {
    num maxValue = 0;
    num minValue = double.infinity;
    num? expNonNull(num? value) {
      if (value == null) {
        return null;
      }
      return (exp(value)) - 1;
    }

    for (var (i, row) in slicedHistory.indexed) {
      var sortedAndDeuplicatedKeys = widget.spec["config"]["metrics"]
          .toSet()
          .toList()
          .map((metric) => metric.replaceAll("system/", "system."));
      for (var metric in sortedAndDeuplicatedKeys) {
        if (row[metric] is num) {
          var rowMetric = expNonNull(row[metric]) ??
              expNonNull(getLastAvailableValue(slicedHistory, i, metric));
          maxValue = max(maxValue, rowMetric ?? maxValue);
          minValue = min(minValue, rowMetric ?? minValue);
        }
      }
    }

    // if minvalue is more than maxvalue, set minvalue to 0
    if (minValue > maxValue) {
      minValue = 0;
    }
    // // Adding a margin of 10%
    //
    // num range = maxValue - minValue;
    // if(range >0){
    //   num margin = range * 0.3; // 10% margin
    //   maxValue += margin;
    //   minValue -= margin;
    // }

    //
    minValue = max(minValue, 0);

    //if both maxValue and minValue are 0, make maxValue 1 and minValue 0
    // if((maxValue == 0) && (minValue == 0)){
    //   maxValue = 1.0;
    //   minValue = 0.0;
    // }

    var logarithmicMinValue = log((minValue) + 1);
    var logarithmicMaxValue = log((maxValue) + 1);
    return {"max": logarithmicMaxValue, "min": logarithmicMinValue};
  }

  Map<String, num> _findDomainAxisBoundsWithMargin(
      List<dynamic> slicedHistory) {
    num maxValue = 0;
    num minValue = double.infinity;

    for (var row in slicedHistory) {
      var value = row[widget.xAxis] ??
          row["_runtime"]; // Replace with the actual logic to get the X-axis value from row
      value = (deExpIt(value));
      maxValue = max(maxValue, value);
      minValue = min(minValue, value);
    }

    if (minValue > maxValue) {
      minValue = 0;
    }

    if ((maxValue == 0) && (minValue == 0)) {
      maxValue = 1.0;
      minValue = 0.0;
    }

    // num range = maxValue - minValue;
    // num margin =log( range * 0.1); // 10% margin
    // maxValue += margin;
    //minValue -= 10;
    // minValue = max(minValue, 0);

    var exponentialMinValue = expIt(minValue); //+ (slicedHistory.length);
    var exponentialMaxValue =
        expIt(maxValue); //+ (slicedHistory.length) ; ///+ (maxValue/4);

    return {"max": exponentialMaxValue, "min": exponentialMinValue};
  }

  static num? getLastAvailableValue(
      dynamic hist, int currentIndex, String key) {
    for (int i = currentIndex - 1; i >= 0; i--) {
      if (hist[i].containsKey(key)) {
        if (hist[i][key].runtimeType != int &&
            hist[i][key].runtimeType != double &&
            hist[i][key].runtimeType != num) {
        } else {
          return hist[i][key];
        }
      }
    }
    return null;
  }

  List<num> gaussianSmoothList(List<num> originalList) {
    //return originalList;
    return applyGaussianSmoothing(
            originalList.map((el) => Point(el, el)).toList())
        .map((e) => e.y)
        .toList();
  }

  List<Map<String, dynamic>> gaussianSmoothListMap(List originalList) {
    //return originalList;
    var outcome = <String, dynamic>{};
    var sortedAndDeuplicatedKeys = widget.spec["config"]["metrics"]
        .toSet()
        .toList()
        .map((metric) => metric.replaceAll("system/", "system."));
    for (var metric in sortedAndDeuplicatedKeys) {
      var resList = originalList.indexed
          .map((v) => (v.$2[metric] ??
              getLastAvailableValue(originalList, v.$1, metric)))
          .toList();
      var hasAnyValue = resList.any((element) => element != null);
      if (hasAnyValue) {
        var headNullCount =
            resList.takeWhile((element) => element == null).length;
        var tailNullCount =
            resList.reversed.takeWhile((element) => element == null).length;
        var nresList = resList
            .sublist(headNullCount, resList.length - tailNullCount)
            .map<num>((e) => e as num)
            .toList();
        var smoothed = gaussianSmoothList(nresList);
        var smoothedHead = List.filled(headNullCount, null);
        var smoothedTail = List.filled(tailNullCount, null);
        var merged = [...smoothedHead, ...smoothed, ...smoothedTail];
        outcome[metric] = merged;
      } else {
        outcome[metric] = resList;
      }
    }

    var newList = <Map<String, dynamic>>[];
    for (var v in originalList.indexed) {
      var (i, row) = v;
      var newRow = Map<String, dynamic>.from(row);
      for (var metric in sortedAndDeuplicatedKeys) {
        newRow[metric] = outcome[metric][i];
      }
      newList.add(newRow);
    }
    return newList;
  }

  (bool, List<charts.Series<dynamic, num>>) _createSeriesList(
      List slicedHistory) {
    List<charts.Series<dynamic, num>> seriesList = [];
    var sortedAndDeuplicatedKeys = widget.spec["config"]["metrics"]
        .toSet()
        .toList()
        .map((metric) => metric.replaceAll("system/", "system."));

    var isAnyDataAvailableForKeys = false;

    for (var metric in sortedAndDeuplicatedKeys) {
      // create a new slicedHistory that basically only adds the metrics every 0.1 increase in domain

      //slicedHistory = newSlicedHistory;
      var series = charts.Series<dynamic, num>(
        keyFn: (dynamic row, _) =>
            ((row[widget.xAxis] ?? row["_runtime"]) + "_" + metric),
        id: metric,
        colorFn: (_, __) => _getColorForMetric(metric),
        // Implement this method
        domainFn: (dynamic row, currentIndex) {
          return (row[widget.xAxis] ??
              row["_runtime"]); // ?? getLastAvailableValue(slicedHistory, currentIndex!,widget.xAxis ) ?? getLastAvailableValue(slicedHistory, currentIndex!,"_runtime"));
        },
        // Assuming xAxis is correctly set
        measureFn: (dynamic row, currentIndex) => (row[metric] ??
            getLastAvailableValue(slicedHistory, currentIndex!, metric)),
        // Ensure 'metric' is a key in your data
        dashPatternFn: slicedHistory!.isNotEmpty
            ? (dynamic row, currentIndex) =>
                ((widget.spec["config"]["overrideMarks"]?[metric] ?? "solid") ==
                        "dotted")
                    ? [1, 2, 0]
                    : null
            : null,
        data: slicedHistory, // Make sure this is structured correctly
      );
      isAnyDataAvailableForKeys = isAnyDataAvailableForKeys ||
          slicedHistory.any((element) =>
              element.keys.contains(metric) && (element[metric] is num));
      seriesList.add(series);
    }

    return (isAnyDataAvailableForKeys, seriesList);
  }

  charts.Color _getColorForMetric(String metric) {
    // Replace with your logic to get the color based on 'spec'
    var colorFromSpec =
        widget.spec["config"]?["overrideColors"]?[metric]?["color"];
    if (colorFromSpec != null) {
      if (colorFromSpec is String) {
        if (colorFromSpec.startsWith("#")) {
          return charts.Color.fromHex(code: colorFromSpec);
        } else if (colorFromSpec.startsWith("rgb")) {
          var rgb =
              colorFromSpec.substring(4, colorFromSpec.length - 1).split(",");
          return charts.Color(
              r: int.parse(rgb[0]), g: int.parse(rgb[1]), b: int.parse(rgb[2]));
        }
      }
    }
    //
    // // get random color from the list
    var color = seedToColor(metric);
    //convert to hex

    return charts.Color.fromHex(code: colorToHex(color));
  }

  String colorToHex(Color color, {bool leadingHashSign = true}) {
    return '${leadingHashSign ? '#' : ''}'
        '${color.red.toRadixString(16).padLeft(2, '0')}'
        '${color.green.toRadixString(16).padLeft(2, '0')}'
        '${color.blue.toRadixString(16).padLeft(2, '0')}';
  }

  List<charts.ChartTitle<num>> _createChartTitles() {
    return widget.spec["config"]["metrics"]
        .map<charts.ChartTitle<num>>((metric) {
      return charts.ChartTitle<num>(metric,
          behaviorPosition: charts.BehaviorPosition.start,
          titleOutsideJustification:
              charts.OutsideJustification.middleDrawArea);
    }).toList();
  }

  List<charts.RangeAnnotationSegment<Object>> getRangeAnnotations(List<dynamic> slicedHistory) {
    if (lastSeenDomain != null) {
      var isLastSeenAnnotable = false;
      var expedLastSeenDomain = lastSeenDomain!;
      var foundIndex = slicedHistory.indexWhere((element) {
        var domain = element[widget.xAxis] ?? element["_runtime"];
        return expedLastSeenDomain <= domain;
      });
      var lastStep = ((slicedHistory.map((e)=>e["_step"]).where((e)=>(e != null))).toList()..sort((a,b)=>a.compareTo(b))).lastOrNull;
      if (lastStep != null) {
        if (foundIndex >= 0) {
          var diffLen = slicedHistory.length - foundIndex;
          if (diffLen < 2) {
            return [];
          }
          return [
            new charts.RangeAnnotationSegment(
                expedLastSeenDomain,
                lastStep + 1,//+ ((lastStep - expedLastSeenDomain) * 0.2),
                charts.RangeAnnotationAxisType.domain,
                endLabel: 'new',
                labelStyleSpec: charts.TextStyleSpec(
                    fontSize: 8,
                    fontWeight: "800",
                    color: charts.MaterialPalette.pink.shadeDefault),
                labelAnchor: charts.AnnotationLabelAnchor.end,
                color:
                    charts.Color.fromHex(code: "#E91E63").darker.darker.darker,
                // Override the default vertical direction for domain labels.
                labelDirection: charts.AnnotationLabelDirection.horizontal),
          ];
        }
      }
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    // Determine the start index for slicing the history data

    // TODO: implement build
    if (widget.spec.containsKey("viewType") &&
        widget.spec["viewType"] == "Run History Line Plot" &&
        isLoaded) {
      var (isAnyDataAvailable, seriesList) = _createSeriesList(slicedHistory);
      if (!isAnyDataAvailable) {
        return Container();
      }
      return Container(
          width: double.infinity,
          margin: EdgeInsets.all(10),
          height: double.infinity,
          padding: (widget.isBordered) ? EdgeInsets.all(15) : null,
          decoration: (widget.isBordered)
              ? BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 2.0,
                  ),
                  borderRadius: BorderRadius.circular(10))
              : null,
          constraints: BoxConstraints(
            maxHeight: 350,
            // maxWidth: double.infinity,
          ),
          child: Stack(
            children: [
              charts.LineChart(
                seriesList,
                //  animate: true,
                defaultRenderer: charts.LineRendererConfig(
                  includeArea: false,
                  stacked: false,
                  strokeWidthPx: 1.0,

                  // layoutPaintOrder: charts.LayoutViewPaintOrder.point + 1,
                ),
                animate: false,
                primaryMeasureAxis: charts.NumericAxisSpec(
                  showAxisLine: true,
                  tickFormatterSpec:
                      charts.BasicNumericTickFormatterSpec(_formatLargeNumber),
                  viewport: ((bounds["min"] is num && bounds["max"] is num) &&
                          (bounds["min"] < bounds["max"]))
                      ? charts.NumericExtents(bounds["min"]!, bounds["max"]!)
                      : null,
                  tickProviderSpec: const charts.BasicNumericTickProviderSpec(
                    desiredTickCount: 7,
                    dataIsInWholeNumbers: false,
                  ),
                  renderSpec: charts.GridlineRendererSpec(
                    labelRotation: 270,
                    labelOffsetFromAxisPx: 13,
                    axisLineStyle: charts.LineStyleSpec(
                      color: charts.MaterialPalette.gray.shade800,
                    ),
                    labelStyle: charts.TextStyleSpec(
                      fontSize: 10,
                      color: charts.MaterialPalette.white,
                    ),
                    lineStyle: charts.LineStyleSpec(
                      color: charts.MaterialPalette.gray.shade800,
                    ),
                  ),
                ),
                domainAxis: charts.NumericAxisSpec(
                  showAxisLine: true,
                  tickFormatterSpec:
                      charts.BasicNumericTickFormatterSpec(_formatDomainAxis),
                  //viewport: charts.NumericExtents(xbounds["min"]!, xbounds["max"]!),
                  viewport: ((xbounds["min"] is num && xbounds["max"] is num) &&
                          (xbounds["min"] < xbounds["max"]))
                      ? charts.NumericExtents(xbounds["min"]!,
                          xbounds["max"]! + (xbounds["max"]! * 0.0001))
                      : null,
                  tickProviderSpec: const charts.BasicNumericTickProviderSpec(
                    desiredTickCount: 8,
                    dataIsInWholeNumbers: false,
                    //   dataIsInWholeNumbers: true,
                  ),
                  renderSpec: charts.GridlineRendererSpec(
                    axisLineStyle: charts.LineStyleSpec(
                      color: charts.MaterialPalette.gray.shade800,
                    ),
                    labelStyle: const charts.TextStyleSpec(
                        fontSize: 10,
                        color: charts.MaterialPalette.white,
                        fontWeight: "500"),
                    lineStyle: charts.LineStyleSpec(
                      color: charts.MaterialPalette.gray.shade800,
                    ),
                  ),
                  //logScale: spec["config"]["xLogScale"] ?? false,
                ),
                layoutConfig: charts.LayoutConfig(
                  leftMarginSpec: charts.MarginSpec.fixedPixel(10),
                  topMarginSpec: charts.MarginSpec.fixedPixel(10),
                  rightMarginSpec: charts.MarginSpec.fixedPixel(10),
                  bottomMarginSpec: charts.MarginSpec.fixedPixel(10),
                ),
                behaviors: [
                  new charts.RangeAnnotation(
                      [...getRangeAnnotations(slicedHistory)]),
                  charts.ChartTitle("Step",
                      titleStyleSpec: const charts.TextStyleSpec(
                          fontSize: 10,
                          fontWeight: "bold",
                          lineHeight: 2.0,
                          color: charts.MaterialPalette.white),
                      behaviorPosition: charts.BehaviorPosition.bottom,
                      // titlePadding: 10,
                      titleOutsideJustification:
                          charts.OutsideJustification.middleDrawArea),
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
                        color: charts.MaterialPalette.white, fontSize: 10),
                  ),
                  //charts.PanAndZoomBehavior(),
                  charts.SelectNearest(
                    eventTrigger: charts.SelectionTrigger.tapAndDrag,
                    selectAcrossAllDrawAreaComponents: true,
                  ),
                  // charts.DomainHighlighter(
                  //   charts.SelectionModelType.info
                  // ),
                  charts.LinePointHighlighter(
                      selectionModelType: charts.SelectionModelType.info,
                      showHorizontalFollowLine:
                          charts.LinePointHighlighterFollowLineType.nearest,
                      showVerticalFollowLine:
                          charts.LinePointHighlighterFollowLineType.nearest),
                ],
                selectionModels: [
                  charts.SelectionModelConfig(
                    type: charts.SelectionModelType.info,
                    changedListener: (charts.SelectionModel model) {
                      widget.onPressed(
                          model,
                          widget.spec["config"]["metrics"]
                              .toSet()
                              .toList()
                              .map((metric) =>
                                  metric.replaceAll("system/", "system."))
                              .toList());
                    },
                  )
                ],
              ),
            ],
          ));
    } else {
      return Container();
    }
  }

  @override
  // TODO: implement wantKeepAlive
  bool get wantKeepAlive => !disposed;
}
