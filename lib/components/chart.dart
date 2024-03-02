import 'dart:async';

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' as material;
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:wandview/utils/utilities.dart';

import '../utils/controllers.dart';

class ChartComponent extends StatefulWidget {
  final int maxHistoryLength;
  final String xAxis;

  final dynamic spec;
  final RxList<Map<String, dynamic>> historyWatchable;
  final Function onPressed;
  final Function lastValuesReport;
  final bool isBordered;
  final bool showLastValues;
  final String runName;
  final String visibilityKey;

  ChartComponent(
      {super.key,
      this.maxHistoryLength = 600,
      this.isBordered = false,
      required  this.visibilityKey,
      this.showLastValues = false,
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
  var paused = false;
  double? get lastSeenDomain {
    var appSessionId = prefs.getString("appSession")!;
    var runName = widget.runName;
    var lt= prefs.getDouble("$appSessionId:$runName:lastSeenStep");
    return lt;
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
    if (_history.lastOrNull != null) {
      var sortedAndDeuplicatedKeys = (widget.spec["config"]["metrics"] ?? [])
          .toSet()
          .toList()
          .map((metric) => metric.replaceAll("system/", "system."))
          .toList();
      widget.lastValuesReport(
          _history.lastOrNull, sortedAndDeuplicatedKeys ?? []);
    }

    if (setToState && this.mounted && !paused) {
      setState(() {
        slicedHistory = _history;
        bounds = _findAxisBoundsWithMargin(slicedHistory);
        xbounds = _findDomainAxisBoundsWithMargin(slicedHistory);
        history = _history;
      });
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

  get isChartValid {

    return widget.spec.containsKey("viewType") &&
        (widget.spec["viewType"] == "Run History Line Plot"
        || widget.spec["viewType"] == "Media Browser"
        ) &&
        (
            (widget.spec["config"]["metrics"] != null)
            || ((widget.spec["config"]["mediaKeys"] != null) && (widget.spec["config"]["mediaKeys"].length > 0))
        );
  }

  @override
  void initState() {
    // TODO: implement initState
    if (isChartValid) {
      SharedPreferences.getInstance().then((_prefs) {
        prefs = _prefs;
        loadUp(widget.historyWatchable.value.toList(), setToState: true);
        historyWatchableStream = widget.historyWatchable.stream.listen((val) {
          if (disposed) {
            return;
          }

          if (this.mounted) {
            loadUp(val, setToState: true);

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
    }

    super.initState();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    disposed = true;
    if (isChartValid) {
      historyWatchableStream.cancel();
    }

    super.dispose();
  }

  String _formatLargeNumber(num? value) {
    if (value == null) {
      return "";
    }
    if (value == 0) {
      return "0";
    }
    value = deLogIt(value, bounds["rawMin"]);
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
    } else if (value < 0.01) {
      return (value.toStringAsExponential(1)); //.toStringAsPrecision(2);
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
    // if (value <= 0) {
    //   return value.floor().toString();
    // }

    var logIndex =(value == 0 ? 1.0.floor() :  deExpIt(value).floor());
    if (logIndex > slicedHistory.length - 1) {
      return "";
    }

    var logValue= slicedHistory[logIndex][widget.xAxis] ?? slicedHistory[logIndex]["_runtime"];
    if (logValue == null) {
      return "";
    }
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

    var sortedAndDeuplicatedKeys = widget.spec["config"]["metrics"]
        .toSet()
        .toList()
        .map((metric) => metric.replaceAll("system/", "system."));
    for (var (i, row) in slicedHistory.indexed) {
      for (var metric in sortedAndDeuplicatedKeys) {
        if (row[metric] is num) {
          var rowMetric = row[metric] ?? getLastAvailableValue(slicedHistory, i, metric);
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
    //minValue = max(minValue, 0);


    //minValue = max(0, minValue- (maxValue-minValue)*0.1);
    //maxValue += ((maxValue-minValue)*0.1);
    //if both maxValue and minValue are 0, make maxValue 1 and minValue 0
    // if((maxValue == 0) && (minValue == 0)){
    //   maxValue = 1.0;
    //   minValue = 0.0;
    // }

    var logarithmicMinValue = logIt((minValue),minValue );
    var logarithmicMaxValue = logIt((maxValue),minValue);
    return {"max": logarithmicMaxValue, "min": logarithmicMinValue, "rawMin": minValue};
  }

  Map<String, num> _findDomainAxisBoundsWithMargin(
      List<dynamic> slicedHistory) {


    var exponentialMinValue = expIt(1); //+ (slicedHistory.length);
    var exponentialMaxValue =
        expIt(slicedHistory.length+1); //+ (slicedHistory.length) ; ///+ (maxValue/4);

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





  (bool, List<charts.Series<dynamic, num>>) _createSeriesList(
      List slicedHistory) {
    List<charts.Series<dynamic, num>> seriesList = [];
    var sortedAndDeuplicatedKeys = widget.spec["config"]["metrics"]
        .toSet()
        .toList()
        .map((metric) => metric.replaceAll("system/", "system."))
        .take(50);

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
         // print("currentIndex= $currentIndex");
          return expIt(currentIndex!+1);
         // return expIt(row[widget.xAxis] ?? row["_runtime"]); // ?? getLastAvailableValue(slicedHistory, currentIndex!,widget.xAxis ) ?? getLastAvailableValue(slicedHistory, currentIndex!,"_runtime"));
        },
        // Assuming xAxis is correctly set
        measureFn: (dynamic row, currentIndex){
          var vx = (row[metric] ??
              getLastAvailableValue(slicedHistory, currentIndex!, metric));
          if(vx == null){
            return null;
          }else{
            return logIt(vx, bounds["rawMin"] ?? 0.0);
          }
        },
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

  List<charts.RangeAnnotationSegment<Object>> getRangeAnnotations(
      List<dynamic> slicedHistory) {
    if (lastSeenDomain != null) {
      var isLastSeenAnnotable = false;
      var expedLastSeenDomain = lastSeenDomain!;
      var smallestStep = slicedHistory.reversed.where((element) {
        var domain = element["_step"] ?? element["_runtime"];
        return expedLastSeenDomain >= domain;
      }).firstOrNull;
      var lastStep = ((slicedHistory
              .map((e) => e["_step"])
              .where((e) => (e != null))).toList()
            ..sort((a, b) => a.compareTo(b)))
          .lastOrNull;
      if (lastStep != null && smallestStep!=null) {
        var smallestStepDomain = smallestStep["_step"] ?? smallestStep["_runtime"];
        if(lastStep>smallestStepDomain) {
          var indexOfFirstLargeStepAfterSmallest = slicedHistory.indexWhere((element) {
            var domain = element["_step"] ?? element["_runtime"];
            return domain > smallestStepDomain;
          });

          var smallestStepDomainExp = expIt(indexOfFirstLargeStepAfterSmallest+1);
          var lastStepExp = expIt(slicedHistory.length+1);
          return [
            new charts.RangeAnnotationSegment(
                smallestStepDomainExp,
                lastStepExp, //+ ((lastStep - expedLastSeenDomain) * 0.2),
                charts.RangeAnnotationAxisType.domain,
                endLabel: 'new',
                labelStyleSpec: charts.TextStyleSpec(
                    fontSize: 8,
                    fontWeight: "800",
                    color: charts.MaterialPalette.pink.shadeDefault),
                labelAnchor: charts.AnnotationLabelAnchor.end,

                color:
                charts.Color
                    .fromHex(code: "#231A21")
                    ,
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
    if (isChartValid && isLoaded) {
      var (isAnyDataAvailable, seriesList) = _createSeriesList(slicedHistory);
      if (!isAnyDataAvailable) {
        if (slicedHistory.length > 0) {
          return Container();
        }
        return Container();
      }
      return VisibilityDetector(key: ValueKey(widget.visibilityKey), onVisibilityChanged: (VisibilityInfo info) {
        if(info.visibleFraction == 0){
          paused = true;
        }else{
          paused = false;
        }
      },
      child: Container(
        padding: (widget.isBordered) ? const EdgeInsets.all(15) : null,
        decoration: (widget.isBordered)
            ? BoxDecoration(
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 2.0,
            ),
            borderRadius: BorderRadius.circular(10))
            : null,
        width: double.infinity,
        margin: const EdgeInsets.all(10),
        constraints: BoxConstraints(
          maxHeight: 350,
        ),
        height: double.infinity,
        child: Column(
          children: [
            Expanded(child:
            Container(
                width: double.infinity,

                height: double.infinity,

                child: charts.LineChart(
                  seriesList,

                  //  animate: true,
                  defaultRenderer: charts.LineRendererConfig(
                    includeArea: false,
                    stacked: false,
                    strokeWidthPx: 1.0,

                    roundEndCaps: true,

                    // layoutPaintOrder: charts.LayoutViewPaintOrder.point + 1,
                  ),
                  animate: false,
                  primaryMeasureAxis: charts.NumericAxisSpec(
                    showAxisLine: true,
                    tickFormatterSpec: charts.BasicNumericTickFormatterSpec(
                        _formatLargeNumber),
                    viewport:
                    ((bounds["min"] is num && bounds["max"] is num) &&
                        (bounds["min"] < bounds["max"]))
                        ? charts.NumericExtents(
                        bounds["min"]!, bounds["max"]!)
                        : null,
                    tickProviderSpec:
                    const charts.BasicNumericTickProviderSpec(
                      desiredTickCount: 5,
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
                        color: charts.MaterialPalette.gray.shade900,
                      ),
                    ),
                  ),
                  domainAxis: charts.NumericAxisSpec(
                    showAxisLine: true,
                    tickFormatterSpec: charts.BasicNumericTickFormatterSpec(
                        _formatDomainAxis),
                    //viewport: charts.NumericExtents(xbounds["min"]!, xbounds["max"]!),
                    viewport: ((xbounds["min"] is num &&
                        xbounds["max"] is num) &&
                        (xbounds["min"] < xbounds["max"]))
                        ? charts.NumericExtents(xbounds["min"]!,
                        xbounds["max"]!)
                        : null,
                    tickProviderSpec:
                    const charts.BasicNumericTickProviderSpec(
                      desiredTickCount: 6,
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
                        color: charts.MaterialPalette.gray.shade900,
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
                    charts.ChartTitle(
                    (widget.xAxis ?? "_step").replaceAll("_", " ").trim().capitalize!
                    ,
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
                          color: charts.MaterialPalette.white,
                          fontSize: 10),
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
                        showHorizontalFollowLine: charts
                            .LinePointHighlighterFollowLineType.nearest,
                        showVerticalFollowLine: charts
                            .LinePointHighlighterFollowLineType.nearest),
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
                )
            )),
            if(widget.showLastValues)
              Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(top: 10),
                  child:
                  SingleChildScrollView(

                    scrollDirection: Axis.horizontal,
                    child: Row(

                      children: [

                        ...((((widget.spec["config"]["metrics"].toSet()
                            .map((metric) => metric.replaceAll("system/", "system."))
                            .toList() as List)
                            ..add("_step")
                          ..add("_runtime")
                          ..add(widget.xAxis)).toSet().toList()

                          ..sort((a,b){
                            // _step then _runtime should be first
                            if(a == widget.xAxis){
                              return -1;
                            }
                            if(b == widget.xAxis){
                              return 1;
                            }
                            if(a == "_step" || a == "_runtime" || a == widget.xAxis){
                              return -1;
                            }


                            if(b == "_step" || a == "_runtime"){
                              return 1;
                            }


                            return a.compareTo(b);
                          })

                        )
                        .where((element) => slicedHistory.lastOrNull?[element] != null)
                        .toList()
                         )
                            .take(10)
                            .map((key) {
                          var lastValues = slicedHistory.last;
                          var valNum = lastValues[key];
                          // if(key == "_step" || key == "_runtime"){
                          //   valNum = (deExpIt(valNum)).toInt();
                          // } else if (key != "_timestamp" && valNum != null) {
                          //   valNum = exp(valNum) - 1;
                          // }
                          if(key == "_step" || key == "_runtime" || key == widget.xAxis){
                            if(valNum != null){
                              valNum = valNum.toInt();
                            }

                          }
                          var value = valNum?.toString();
                          if(valNum != null && value != null){
                            if(value.split(".").length > 1){
                              value = valNum.toStringAsPrecision(3);
                            }else{
                              value = value.toString();
                            }
                          }


                          var dartColor = seedToColor(key);
                          return Container(
                            margin: EdgeInsets.only(right: 5),
                            decoration: BoxDecoration(
                                color: dartColor,
                                borderRadius: BorderRadius.circular(6)
                            ),
                            padding: EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(key, style: TextStyle(
                                    fontSize: 6,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white.withOpacity(0.8)
                                ),),
                                Text(value ?? "NONE", style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white
                                ),),
                              ],
                            ),
                          );
                        }).toList()
                      ],
                    ),
                  )),
            //Text(deExpIt(lastSeenDomain ?? 1.0).toString()+" - "+deExpIt(slicedHistory.lastOrNull?["_step"] ?? 1.0).toString())
          ],
        ),
      ));
    } else {
      return Container();
    }
  }

  @override
  // TODO: implement wantKeepAlive
  bool get wantKeepAlive => !disposed;
}
