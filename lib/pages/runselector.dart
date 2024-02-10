import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../utils/controllers.dart';
import '../utils/utilities.dart';
//
// class LineChartCanvas extends StatelessWidget {
//   final List<dynamic> history;
//   final Set<String> histKeys;
//   final Set<String> activeMetrics;
//   final num? lastSeenStep;
//   final ChartData chartData;
//   final Map<String, Color> histColors;
//
//   late LineChartPainter lineChartPainter;
//
//    LineChartCanvas(
//       {super.key,
//       required this.history,
//       this.lastSeenStep,
//       required this.histKeys,
//       required this.chartData,
//       required this.histColors,
//       required this.activeMetrics}){
//     this.lineChartPainter = LineChartPainter(
//         history: this.history,
//         lastSeenStep: this.lastSeenStep,
//         histKeys: this.histKeys,
//         chartData: this.chartData,
//         histColors: this.histColors,
//         activeMetrics: this.activeMetrics);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return CustomPaint(
//       size: const Size(double.infinity, 150), // Set the canvas size
//       painter: lineChartPainter,
//     );
//   }
// }

// Function to apply Gaussian smoothing to a list of points
class Point {
  final num x;
  final double y;
  final String? action;

  Point(this.x, this.y, {this.action});
}

class Series {
  List<Point> points;
  final Paint paint;

  late Paint lineStyle;

  Series(this.points, this.paint);
}
// child: CircularProgressIndicator(
// strokeWidth: 1,
// value: run["progress"],
// color: Colors.white,
// )
List<Point> applyGaussianSmoothing(List<Point> inputSeries,
    {double sigma = 3.0, int kernelSize = 4}) {
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

class LineChartPainter extends CustomPainter {
  final num? lastSeenDomain;
  final ChartData chartData;
  final String painterId;
  bool isPaintedAlready = false;

  LineChartPainter(
      {
      required this.chartData,
      this.lastSeenDomain,
        required this.painterId}) {
    //repaint the canvas every 15 seconds to prevent data stallign

  }


  @override
  void paint(Canvas canvas, Size size) {
    print("Repainting: ${this.painterId}");
   // if(isPaintedAlready){
   //   return;
   // }
   // isPaintedAlready = true;
    // Define your data for multiple series
    // var hist = history.map((hst) => (hst is String) ?  jsonDecode(hst) : hst).toList();

    var sizeXToDraw = null;
    // return;
    //smoothed renderingActions



    if (lastSeenDomain is num ) {
      var lastSeenStepExp = lastSeenDomain!;
      if(lastSeenStepExp! != null){
        sizeXToDraw = null;
        var largestValue = 0.0;
        for (var (pnt, series) in chartData.smoothedSeriesItems) {
           for (var point in series.points.reversed) {
             largestValue = max(largestValue, point.x.toDouble());
             if (point.x <= lastSeenStepExp) {
               sizeXToDraw = transform(point.x, size.width, chartData.min_x.toDouble(), chartData.max_x.toDouble(), alpha: 0.9);
               sizeXToDraw  += (size.width * 0.05);
               break;
             }
           }
           if (sizeXToDraw != null) {
             break;
           }
        }
           // transform(lastSeenStepExp, size.width, chartData.min_x.toDouble(), chartData.max_x.toDouble(), alpha: 0.9);
        if(sizeXToDraw != null && (largestValue>lastSeenStepExp)){


        var bgPaint = Paint()
          ..color = Colors.pink.withOpacity(0.1)
          ..style = PaintingStyle.fill
          ..strokeWidth = 1.0;
        if (sizeXToDraw < 0) {
          sizeXToDraw = 0;
        }
          var drawRect = Rect.fromLTWH(
              sizeXToDraw, 0, size.width - sizeXToDraw, size.height);

          canvas.drawRect(drawRect, bgPaint);

          var paint = Paint()
            ..color = Colors.pink.withOpacity(0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0;

          canvas.drawLine(
              Offset(sizeXToDraw, 0), Offset(sizeXToDraw, size.height), paint);
        }
      }

    }

    for (var (pnt, series) in chartData.smoothedSeriesItems) {
      var _points = series.points; // applyGaussianSmoothing();

      var path = Path();
      var done = false;
      (num, num)? prevPoint = null;
      for (var (ix, point) in _points.indexed) {
        var x = transform(point.x, size.width, chartData.min_x.toDouble(), chartData.max_x.toDouble(), alpha: 0.9);
        var y = transform(point.y, size.height, chartData.min_y.toDouble(), chartData.max_y.toDouble());

        x += (size.width * 0.05);
        y = (size.height) - y - (size.height * 0.1); //
        if (ix == 0) {
          path.moveTo(x, y);
          path.lineTo(x, y);
        } else {
          path.lineTo(x, y);
        }
        prevPoint = (x, y);
        done = true;
      }
      if (done) {
        canvas.drawPath(path, series.lineStyle);
      }
    }
  }

  bool isTooClose(Point p1, Point p2, double threshold) {
    return (p1.x - p2.x).abs() < threshold && (p1.y - p2.y).abs() < threshold;
  }



  double transform(num x, double boundary, double min_x, double max_x,
      {alpha = 0.8}) {
    // Scale and translate the x-coordinate to fit the canvas size
    return ((x - min_x) / (max_x - min_x)) * (boundary * alpha);
  }

  @override
  bool shouldRepaint(LineChartPainter oldDelegate) {

    // TODO: implement shouldRepaint
    return (oldDelegate.lastSeenDomain != this.lastSeenDomain) || (oldDelegate.chartData != this.chartData);
  }

}


String formatDuration(Duration duration) {
  if (duration.inSeconds < 10) {
    return 'just now';
  } else if (duration.inSeconds < 60) {
    return '${duration.inSeconds} secs ago';
  } else if (duration.inMinutes < 60) {
    if(duration.inMinutes == 1){
      return '${duration.inMinutes} min ago';
    }
    return '${duration.inMinutes} mins ago';
  } else if (duration.inHours < 24) {
    if(duration.inHours == 1){
      return '${duration.inHours} hr ago';
    }
    return '${duration.inHours} hrs ago';
  } else {
    if(duration.inDays == 1){
      return '${duration.inDays} day ago';
    }
    return '${duration.inDays} days ago';
  }
}

num? getLastAvailableValue(List<dynamic> hist, int currentIndex, String key) {
  for (int i = currentIndex - 1; i >= 0; i--) {
    if (hist[i].containsKey(key)) {
      if (hist[i][key] is num) {
        return hist[i][key];
      }
    }
  }
  return null;
}

List<List<Point>> calculateSeriesData((List<dynamic>, Set<String>) message)  {
  var history = message.$1;
  var histKeys = message.$2;
  if (history == null || histKeys == null) {
    return [];
  }
  var seriesData = List.generate(histKeys.length, (index) => <Point>[]);
  for (var (i, h) in history.indexed) {
    var domain = (h["_step"] ?? h["_runtime"]) as num;
    for (var (j,key) in histKeys.indexed) {
      if(h[key] is num){
        seriesData[j].add(
            Point(domain, h[key]!.toDouble()));
      } else {
        var lastValue = getLastAvailableValue(history, i, key);
        if (lastValue != null) {
          seriesData[j].add(
              Point(domain, lastValue!.toDouble()));
        }
      }

    }
  }
  return seriesData;
}

class ChartData {
  final List<num> sortedX;
  final num min_x;
  final num max_x;
  final num min_y;
  final num max_y;
  final List<(Paint, Series)> smoothedSeriesItems;

  ChartData(this.sortedX, this.min_x, this.max_x, this.min_y, this.max_y,
      this.smoothedSeriesItems);
}

prepareChartData(PrepareChartInput input) async {
  var timeNow = DateTime.now();

  var compressedInputs = input.metrics ?? await isolatedRun(input.history!);
  var seriesData = await calculateSeriesData((compressedInputs, input.histKeys));
  final chartData = input.histKeys.indexed
      .where((element) => input.activeMetrics.contains(element.$2))
      .map((xl) {
    var (i,hkey) = xl;
    // generate a random color, so it's readable , and hash "hkey" to get the same color for the same key

    var color = input.histColors[hkey]!;
    var paint = Paint()..color = color;

    paint.style = PaintingStyle.stroke;
    paint.strokeCap = StrokeCap.round;
    paint.color = paint.color.withOpacity(0.99);
    paint.strokeWidth = 1.0;
    var series = Series(seriesData[i], paint);
    series.lineStyle = paint;
    return (paint, series);
  }).toList();


  var foldedPoints = chartData.map((e) => e.$2.points).fold(<Point>[],
      (previousValue, element) => [...previousValue, ...element]).toList();
  var x_values2 = foldedPoints.map((e) => (e.x).toDouble()).toList();
  var y_values2 = foldedPoints.map((e) => (e.y).toDouble()).toList();
  if (x_values2.length < 1) {
    return;
  }
  if (y_values2.length < 1) {
    return;
  }
  var sortedX = x_values2.toList()..sort();
  var min_x = x_values2.reduce(min).toDouble();
  var max_x = x_values2.reduce(max).toDouble();
  var min_y = y_values2.reduce(min).toDouble();
  var max_y = y_values2.reduce(max).toDouble();
  var timeAfter = DateTime.now();
  var calculatedDuration = timeAfter.difference(timeNow);
  print("Time took for computing runSelector : ${calculatedDuration.inSeconds}s");

  return ChartData(sortedX, min_x, max_x, min_y, max_y, chartData);
}

class PrepareChartInput{
  final Set<String> histKeys;
  final Map<String, Color> histColors;
  final List<Map<String,dynamic>>? history;
  final Set<String> activeMetrics;
  final List<Map<String,dynamic>>? metrics;

  PrepareChartInput({required Set<String> this.histKeys,
    required Map<String, Color> this.histColors,
     this.history,
    this.metrics,
    required Set<String> this.activeMetrics});

}

class RunItem extends StatefulWidget {
  final String runId;
  final dynamic run;
  final loadHistory;


  RunItem({super.key, required this.runId, this.run, this.loadHistory});

  @override
  State<StatefulWidget> createState() {
    return RunItemState(runId: runId, run: run);
  }
}
class RunItemState extends State<RunItem> with AutomaticKeepAliveClientMixin {
  final String runId;

  final dynamic run;
  var activeMetrics = <String>{};
  var prevMetrics = <Map<String,dynamic>>[];
  var prevSystemMetrics = <Map<String,dynamic>>[];
  Duration? lastUpdatedDuration = null;
  ChartData? chartData = null;
  var histColors = <String, Color>{};
  var histKeys = <String>{};
  var isLoading = true;
  num? get lastSeenDomain {
    var appSessionId = _prefs.getString("appSession")!;
    var runName = run["name"];
    return _prefs.getDouble("$appSessionId:$runName:lastSeenStep");
  }

  RunItemState({required this.runId, this.run}){

  }

  late SharedPreferences _prefs;

  void changeActiveMetrics(Set<String> activeMetrics) async {
    // save to local storage, run["id"] + "activeMetrics"
    _prefs.setStringList(run["id"] + "activeMetrics", activeMetrics.toList());
    setState(() {

      isLoading = true;
    });
    try{
      var _chartData= await compute(prepareChartData, PrepareChartInput(histKeys: histKeys,
          histColors: histColors,
          metrics: this.prevMetrics,
          activeMetrics: activeMetrics));
      setState(() {
        isLoading = false;
        this.chartData = _chartData;
      });
    }catch(e){
      setState(() {
        isLoading = false;
      });
    }


  }


  List<dynamic> postFirstLoad(List<dynamic> structuredHistory){

    var histKeys = <String>{};

    for (var h in structuredHistory) {
      histKeys.addAll((h).keys);
    }
    histKeys = histKeys
        .where((element) =>
    !element.startsWith("l__") &&   !element.startsWith("_") && !["lr"].contains(element))
        .take(10)
        .toSet();
    // sort histKeys in a way small keys come first
    histKeys = (histKeys.toList()..sort((a, b) => a.length.compareTo(b.length))).toSet();
    var _activeMetrics = _prefs.getStringList(run["id"] + "activeMetrics");
    var _lastSeenStep = _prefs.getDouble(run["name"] + "prevLastSeenStep") ?? 0;
    var simpleKeys = histKeys.where((element) => !element.contains("step") && !element.contains("epoch")).toSet();
    if(simpleKeys.length < 1){
      simpleKeys = histKeys;
    }
    var analyzedActiveMetrics= ((_activeMetrics == null)  || (_activeMetrics.isEmpty))? (simpleKeys.take(6).toSet()) : _activeMetrics.toSet()!;//(.isEmpty ?  : histKeys.take(4).toSet());


    var histColors = <String, Color>{};
    var i = 0;
    for (var key in histKeys.toList()) {
      // generate a random color, so it's readable , and hash "hkey" to get the same color for the same key
      var color = seedToColor(
          key); //suitableColors[key.hashCode % suitableColors.length];
      i++;
      histColors[key] = color;
    }



    return [analyzedActiveMetrics,_lastSeenStep,  histKeys,histColors];
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    SharedPreferences.getInstance().then((value) {
      _prefs = value;
      loop(firstLoop: true);
    });

  }

  var terminated = false;
  var paused = false;

  void loop({firstLoop = false}) async {
    if ((run["state"] == "finished") && !firstLoop) {
      return;
    }
    if(!paused){
      try{
        var (metrics, systemMetrics, hasChanged) = await widget.loadHistory(
            run["name"], run["project"]["name"], run["project"]["entityName"],
            allowCache: firstLoop,
            onProject: true,
            previousMetrics:prevMetrics ,
            previousSystemMetrics: prevSystemMetrics

        );
        if (metrics != null && (hasChanged || firstLoop)) {
          // if (ranHistory.length > 5000) {
          //   ranHistory = ranHistory.sublist(
          //       ranHistory.length - 5000, ranHistory.length);
          // }
          print("Gotten the data:)");

          this.prevMetrics = metrics;
          this.prevSystemMetrics = systemMetrics;
          print("Processed the data:)");




          var lastUpdate = this.prevMetrics.lastOrNull;


          if(firstLoop){
            var vals =  postFirstLoad(this.prevMetrics);
            print("Post-Processed the data:)");
            activeMetrics = vals[0];

            histKeys = vals[2];
            histColors = vals[3];
          }

          print("Will compute the data:)");
          var _chartData= await compute(prepareChartData,PrepareChartInput(histKeys: histKeys,
              histColors: histColors,
              metrics: this.prevMetrics,
              activeMetrics: activeMetrics));

          print("Computed the data:)");
          if(this.mounted){
            setState(() {
              this.chartData = _chartData;

              this.activeMetrics = activeMetrics;
              this.histKeys = histKeys;
              this.histColors = histColors;
              if(firstLoop){
                isLoading = false;


              }
              if(lastUpdate != null){
                double? timestamp = lastUpdate["l___timestamp"] ?? lastUpdate["_timestamp"];
                if(timestamp != null){
                  this.lastUpdatedDuration =DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(timestamp.toInt() * 1000));
                }

              }
            });
            // force a repaint
          }

        } else {
          if(!hasChanged){
            print("No change in data");

          }
        }
      }catch( e, trace){
        print("Error: ${e}");
        print("Trace: ${trace}");
        // rethrow;
      }
    }else{
      print("Paused skipping logging for now");
    }

    if(!firstLoop){
      await Future.delayed(Duration(seconds: 6));
    }

    if (!terminated && this.mounted) {
     loop();
    }
  }

  @override
  void activate() {

    paused = false;
    super.activate();
  }
  @override
  void deactivate() {
    paused = true;
    super.deactivate();
  }





  @override
  void dispose() {
    // TODO: implement dispose
    terminated = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var isEmpty = (chartData == null) || chartData!.smoothedSeriesItems.isEmpty;
    var titleByState = {
      "running": "Running",
      "finished": "Finished",
      "crashed": "Crashed",
    };

    var colorByState = {
      "running": Colors.green,
      "finished": Colors.green.withOpacity(0.1),
      "crashed": Colors.red.withOpacity(0.1),
    };
    return  VisibilityDetector(key: ValueKey(runId), child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            GestureDetector(
                onTap: () {
                  Get.toNamed("/charts", arguments: [run["id"]]);
                },
                child: Card(
                  // color: Colors.white,
                    elevation: 0,
                    // surfaceTintColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border:
                        Border.all(color: Colors.white.withOpacity(0.1)),
                        // color: Colors.grey.shade200,
                      ),
                      padding: EdgeInsets.all(3),
                      width: double.infinity,
                      child: (isEmpty || isLoading || (chartData == null))
                          ? Container(
                        width: double.infinity,
                        alignment: Alignment.center,
                        height: 150,
                        child: isLoading ?
                        const Text("Loading...")
                            : const Text("No data available"),
                      )
                          :CustomPaint(
                        key: Key(run["id"]+"_PAINTER"),
                        size:  Size(double.infinity, 150), // Set the canvas size
                        painter: LineChartPainter(
                            painterId:  run["id"],
                            lastSeenDomain: this.lastSeenDomain,
                            chartData: this.chartData!),
                      ),
                    ))),
            Container(
              padding: const EdgeInsets.fromLTRB(5, 5, 5, 5),
              width: double.infinity,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      flex: 1,
                      child: Container(
                          child: Column(
                            children: [
                              Container(
                                  width: double.infinity,
                                  child: Row(
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            run["displayName"],
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,

                                                fontSize: 18),
                                          ),
                                          Container(
                                            // margin: EdgeInsets.only(left: 10),
                                            decoration: BoxDecoration(
                                                color: colorByState[run["state"]]!,
                                                borderRadius:
                                                BorderRadius.circular(4.0)),
                                            padding: EdgeInsets.symmetric(
                                                vertical: 1.0, horizontal: 4.0),
                                            child: Row(

                                              children: [
                                                if (run["state"] == "running")
                                                  Container(
                                                    margin: EdgeInsets.only(right: 5),
                                                    child: Icon(
                                                      Icons.refresh,
                                                      size: 8,
                                                      color: Colors.white,
                                                    ),
                                                  )
                                                else if (run["state"] == "crashed")
                                                  Container(
                                                    margin: EdgeInsets.only(right: 5),
                                                    child: Icon(
                                                      Icons.error,
                                                      size: 8,
                                                      color: Colors.red,
                                                    ),
                                                  )
                                                else if (run["state"] == "finished")
                                                    Container(
                                                      margin: EdgeInsets.only(right: 5),
                                                      // width: 5,
                                                      // height: 5,
                                                      child: Icon(
                                                        Icons.check,
                                                        size: 8,
                                                        color: Colors.green,
                                                      ),
                                                    ),
                                                Text(
                                                  titleByState[run["state"]]!,
                                                  style: TextStyle(
                                                      fontSize: 9,
                                                      color: colorByState[run["state"]]!
                                                          .opacity >
                                                          0.2
                                                          ? Colors.white
                                                          : colorByState[run["state"]]!
                                                          .withOpacity(1.0),
                                                      fontWeight: FontWeight.bold),
                                                )
                                              ],
                                            ),
                                          )
                                        ],),

                                    ],
                                  )),
                              Container(
                                margin: EdgeInsets.only(
                                    top: (histKeys!.length > 0) ? 10 : 0),
                                width: double.infinity,
                                child: Wrap(
                                  spacing: 5,
                                  runSpacing: 5,
                                  alignment: WrapAlignment.start,
                                  runAlignment: WrapAlignment.start,
                                  children: [
                                    ...histKeys
                                        .where(
                                            (element) => !element.startsWith("_"))
                                        .map((hkey) {
                                      return GestureDetector(
                                        child: Container(
                                          // margin: EdgeInsets.only(right: 5),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                            constraints:
                                            BoxConstraints(minWidth: 50),
                                            //alignment: Alignment.center,

                                            decoration: BoxDecoration(
                                              color: activeMetrics.contains(hkey)
                                                  ? histColors[hkey]
                                                  : histColors[hkey]
                                                  ?.withOpacity(0.1),
                                              borderRadius:
                                              BorderRadius.circular(5),
                                            ),
                                            child: Text(
                                              hkey,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: activeMetrics.contains(hkey)
                                                    ? Colors.white
                                                    : histColors[hkey]
                                                    ?.withOpacity(0.7),
                                              ),
                                              textAlign: TextAlign.center,
                                            )),
                                        onTap: () {
                                          setState(() {
                                            if (activeMetrics.contains(hkey)) {
                                              activeMetrics.remove(hkey);
                                            } else {
                                              //if activeMetrics.length < 6, add it, else, remove the first one and add it
                                              if (activeMetrics.length < 10) {
                                                activeMetrics.add(hkey);
                                              } else {
                                                activeMetrics
                                                    .remove(activeMetrics.first);
                                                activeMetrics.add(hkey);
                                              }
                                            }
                                            changeActiveMetrics(activeMetrics);
                                          });
                                        },
                                      );
                                    }).toList()
                                  ],
                                ),
                              ),


                            ],
                          ))),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if(this.lastUpdatedDuration!=null) Container(
                        margin: EdgeInsets.only(bottom: 5),
                        child: Text(
                          "Updated "+formatDuration(this.lastUpdatedDuration!),
                          style: TextStyle(fontSize: 8.0, height: 0.8, color: Colors.white.withOpacity(0.6)),
                        ),
                        alignment: Alignment.bottomRight,
                      ),

                      GestureDetector(

                        child: Container(
                          width: 35,
                          height: 35,
                          margin: EdgeInsets.only(top: 5),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          alignment: Alignment.center,
                          child: Icon(Icons.chevron_right,
                              size: 20, color: Colors.white),
                        ),
                        onTap: () {
                          Get.toNamed("/charts", arguments: [run["id"]]);
                        },
                      )
                    ],)

                ],
              ),
            ),
          ],
        )), onVisibilityChanged: (info){
     if(info.visibleFraction> 0.2){
       paused =false;
     }else{
       paused = true;
     }
    });
  }

  @override
  // TODO: implement wantKeepAlive
  bool get wantKeepAlive => true;
}

class HomePage extends StatelessWidget {
  HomePage({super.key});

  final appController = Get.find<AppController>();

  get loadHistory => appController.loadHistory;

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Scaffold(
        body: Container(
            width: double.infinity,
            height: double.infinity,
            // color: Colors.black26,
            child: Column(
              children: [
                Expanded(
                    flex: 1,
                    child: SafeArea(
                      child: Container(
                          width: double.infinity,
                          child: LayoutBuilder(
                            builder: (context, constraint) {
                              return Obx(() {
                                var runs = appController.projects.firstWhere(
                                        (element) =>
                                    element["id"] ==
                                        appController
                                            .selectedProject.value)["runs"];
                                return RefreshIndicator(
                                    triggerMode:
                                    RefreshIndicatorTriggerMode.anywhere,
                                    onRefresh: () async {
                                      await appController
                                          .loadRunsAndProjects();
                                    },
                                    child: SingleChildScrollView(
                                        physics:
                                        AlwaysScrollableScrollPhysics(),
                                        child: Container(
                                          width: double.infinity,
                                          height: constraint.maxHeight,
                                          child: Column(
                                            children: [
                                              SizedBox(
                                                width: double.infinity,
                                                child: SingleChildScrollView(
                                                  padding: EdgeInsets.only(
                                                      left: 10, right: 15),
                                                  scrollDirection:
                                                  Axis.horizontal,
                                                  child:  Row(
                                                    children: [
                                                      ...appController
                                                          .projects
                                                          .map((project) {
                                                            var selected = appController.selectedProject.value ==
                                                                project[
                                                                "id"];
                                                        return Container(
                                                          key: Key(
                                                              project[
                                                              "id"]),
                                                          margin: const EdgeInsets
                                                              .symmetric(
                                                              horizontal:
                                                              5,
                                                              vertical:
                                                              10),
                                                          child:
                                                          ElevatedButton(
                                                            onPressed:
                                                                () {
                                                              appController
                                                                  .selectProject(
                                                                  project["id"]);
                                                            },

                                                            style:
                                                            ButtonStyle(
                                                              side: MaterialStateProperty.all<BorderSide>(
                                                                  BorderSide(width: 1.0, color:selected ? Colors.blueAccent : Colors.white.withOpacity(0.5))),
                                                              padding:MaterialStateProperty.all<EdgeInsets>(
                                                                  EdgeInsets.symmetric(vertical: 5, horizontal: 15)),
                                                              backgroundColor: MaterialStateProperty.all(
                                                                  selected? Colors.blueAccent
                                                                  : Colors.white.withOpacity(0.1)),
                                                              foregroundColor: MaterialStateProperty.all(selected
                                                                  ? Colors
                                                                  .white
                                                                  : Colors
                                                                  .white),

                                                            ),
                                                            child: Text(
                                                                project[
                                                                "name"]),
                                                          ),
                                                        );
                                                      }).toList()
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              if (runs.length > 0)
                                                Expanded(
                                                  child: Container(
                                                      child: ListView.builder(
                                                        addAutomaticKeepAlives:
                                                        true,

                                                        itemBuilder:
                                                            (context, index) {
                                                          var run = runs[index];
                                                          return RunItem(
                                                            key: Key(
                                                                "_" +
                                                                run["id"]),
                                                            runId: run["id"],
                                                            run: run,
                                                            loadHistory: loadHistory,

                                                          );
                                                        },
                                                        itemCount: runs.length,
                                                      )),
                                                )
                                              else
                                                Expanded(
                                                    child: Container(
                                                      child: Text(
                                                          "No runs available"),
                                                      alignment: Alignment.center,
                                                    ))
                                            ],
                                          ),
                                        )));
                              });
                            },
                          )),
                    )),
                // Expanded(
                //     flex: 1,
                //     child: Container(
                //       width: double.infinity,
                //       color: Colors.blue,
                //       child: ,
                //     )),
                appController.userProfile.value != null
                    ? Container(
                  color: Colors.grey.shade900,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 15),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CachedNetworkImage(
                        imageUrl:
                        appController.userProfile.value!.photoUrl,
                        width: 40,
                        height: 40,
                        errorWidget: (context, url, error) =>
                            Icon(Icons.error),
                        progressIndicatorBuilder:
                            (context, url, downloadProgress) =>
                            CircularProgressIndicator(
                                value: downloadProgress.progress),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appController.userProfile.value!.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.white),
                            ),
                            Text(
                              appController.userProfile.value!.email,
                              style: TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                        flex: 1,
                      ),
                      IconButton(
                          onPressed: () {
                            appController.logout();
                          },
                          icon: Icon(
                            Icons.logout,
                            color: Colors.red,
                          ),
                          style: ButtonStyle(
                            backgroundColor:
                            MaterialStateProperty.all(Colors.white),
                          ))
                    ],
                  ),
                )
                    : Container(),
              ],
            )));
  }
}
