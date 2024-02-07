import 'package:charts_flutter/flutter.dart' hide Axis, TextStyle;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:wandview/components/chart.dart' ;
import "dart:math";
import '../utils/controllers.dart';
import '../utils/utilities.dart';
class ChartScreenPage extends StatefulWidget {
  ChartScreenPage({super.key});


  @override
  _ChartScreenPageState createState() => _ChartScreenPageState();

}

class _ChartScreenPageState extends State<ChartScreenPage> {
  final appController = Get.find<AppController>();
  bool terminated = false;
  dynamic run;

  var lastValues = <String, num>{}.obs;
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    loop(firstLoop: true);
  }

  void loop({firstLoop=false}) async {
    if (terminated) return;
    if(Get.arguments == null){
      terminated = true;
      return;
    }
    this.run = appController.runs.firstWhere((element) => element["id"] == Get.arguments[0]);

    await appController.loadHistory(run["name"], run["project"]["name"], run["project"]["entityName"],
        allowCache: firstLoop
    );
    if(!firstLoop) {
      await Future.delayed(Duration(seconds: 5));
    }
    if (!terminated) {
      loop();
    }
  }

  @override
  void dispose() {
    terminated = true;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    //appController.clearHistory();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    if(Get.arguments == null || (Get.arguments is! List)){
      terminated = true;
      return Container();
    }
    final [chartId, panel, xAxis, section, isSystemMetrics] = Get.arguments;

    // Getting the screen size


    return Scaffold(
      body: SafeArea(
        child: Container(
          padding: EdgeInsets.only(top: 20, bottom: 20, left: 0, right: 20),
          width: double.infinity, height: double.infinity,child: Stack(
          // width: screenSize.height,
          // height: screenSize.height,
          //color: Colors.black,
          children:[
            LayoutBuilder(
            builder: (context, constraints) {
              return OverflowBox(
                  maxWidth: constraints.maxHeight,
                  maxHeight:  constraints.maxWidth,
                  child:Transform.rotate(
                angle: pi / 2,
                child: Container(
                  // Set the width and height to match the rotated screen dimensions
                  width: constraints.maxHeight,
                  height: constraints.maxWidth,
                  child: Column(children: [
                    Expanded(flex: 1,child:
                    ChartComponent(
                      runName: run["name"],
                      key: Key(section["name"] + panel["__id__"] + xAxis + "_chart"),
                      historyWatchable: isSystemMetrics ? appController.systemMetrics : appController.runHistory,
                      spec: panel,
                      xAxis: xAxis, onPressed: (SelectionModel model, List<dynamic> metrics ) {
                      Map<String,num> _values = {};
                      model.selectedDatum.forEach((SeriesDatum datumPair) {
                        (datumPair.datum as Map).forEach(
                                (key, value) {
                              if (value is num){
                                if(key == "_runtime" || key == "_step"){
                                  _values[key] = (deExpIt(value)).floor() as num;
                                }else{
                                  if (metrics.contains(key)){
                                    _values[key] = (exp(value)-1) as num;
                                  }

                                }

                              }
                            }
                        );
                        //_values[datumPair.series.id] = ;
                      });
                      _values = {...(lastValues.map((key, value) => MapEntry(key, value))),..._values};
                      var entries = _values.entries.toList()..sort((a,b){
                        // _step then _runtime should be first
                        if(a.key == "_step" || a.key == "_runtime"){
                          return -1;
                        }
                        if(b.key == "_step" || a.key == "_runtime"){
                          return 1;
                        }

                        return a.key.compareTo(b.key);
                      });
                      lastValues.clear();
                      lastValues.addEntries(entries);


                    },
                      lastValuesReport: (datum) {
                        Map<String,num> _values = {};
                        (datum as Map).forEach(

                                (key, value) {
                              if (value is num){
                                if(key == "_runtime" || key == "_step"){
                                  _values[key] = ((value)).floor() as num;
                                }else{
                                  _values[key] = ((value)) as num;

                                }
                              }

                            }
                        );
                        var entries = _values.entries.toList()..sort((a,b){
                          // _step, _runtime, ...
                          if(a.key == "_step" || a.key == "_runtime"){
                            return -1;
                          }
                          if(b.key == "_step" || a.key == "_runtime"){
                            return 1;
                          }

                          return a.key.compareTo(b.key);
                        });
                        lastValues.clear();
                        lastValues.addEntries(entries);
                      },
                      maxHistoryLength: 100000,

                    )
                      ,)
                    ,
                    Obx(()=>
                    Container(
                      width: double.infinity,
                      height: 60,
                       alignment: Alignment.centerLeft,
                       padding: EdgeInsets.symmetric(vertical: 10),

                    //   color: Colors.grey.shade100,
                      child: SingleChildScrollView(

                        scrollDirection: Axis.horizontal,
                        child: Row(

                          children: [
                            ...lastValues.keys
                                .map((key) {
                              var valNum = lastValues[key];
                              var value = valNum?.toString();
                              if(valNum != null && value != null){
                                if(value.split(".").length > 1){
                                  value = valNum.toStringAsPrecision(4);
                                }else{
                                  value = value.toString();
                                }
                              }



                              return Container(
                                margin: EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                    color: seedToColor(key),
                                    borderRadius: BorderRadius.circular(7)
                                ),
                                padding: EdgeInsets.only(top: 7, bottom: 4, left: 8, right: 16),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(key, style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white.withOpacity(0.8)
                                    ),),
                                    Text(value ?? "NONE", style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white
                                    ),),
                                  ],
                                ),
                              );
                            }).toList()
                          ],
                        ),
                      )
                    ))
                  ],),
                ),
              ));
            },
          )],
        ),),
      ),
    );
  }

}
