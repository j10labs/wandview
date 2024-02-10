import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:wandview/components/chart.dart';

import '../utils/controllers.dart';
class ChartsPage extends StatefulWidget {
  ChartsPage({super.key});

  @override
  _ChartsPageState createState() => _ChartsPageState();
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

class _ChartsPageState extends State<ChartsPage> {
  final appController = Get.find<AppController>();
  bool terminated = false;
  var runId = Get.arguments[0];
  var sections = [];

  late Map<String,RxList<Map<String, dynamic>>> metricBySection;
  late StreamSubscription historySubscription;

  late Map<String,dynamic> chartInfo;
  late dynamic run;
  late dynamic chartId;
  late dynamic spec;
  late dynamic panelBankConfig;
  var lastUpdatedDuration = (null as Duration?).obs;
  @override
  void initState() {
    super.initState();
    appController.clearHistory();


    this.chartId = Get.arguments[0];
    this.run = appController.runs.firstWhere((element) => element["id"] == chartId);
    this.chartInfo  = appController.chartInfo[this.run["project"]["id"]][0];
    this.spec = this.chartInfo["spec"];
    this.panelBankConfig = this.spec["panelBankConfig"];

    this.sections = (this.panelBankConfig["sections"] as List<dynamic>).where((section){
      return section["panels"].where((panel){

        return  panel.containsKey("viewType") &&
            panel["viewType"] == "Run History Line Plot" &&
            (panel["config"]["metrics"] != null);
      }).length > 0;
    }).toList();
    historySubscription = appController.runHistory.listen((slicedHistory) {
      var validSectionNames = <String>{};
      for (var section in this.sections) {
        //var sectionWideXAis = section["localPanelSettings"]?["xAxis"];
        var isSystemMetrics = section["name"] == "System";
        if(!isSystemMetrics){
          var panels = section["panels"];
          for (var panel in panels){
            if(panel.containsKey("viewType") &&
                panel["viewType"] == "Run History Line Plot" &&
                (panel["config"]["metrics"] != null)){
              var sortedAndDeuplicatedKeys = panel["config"]["metrics"]
                  .toSet()
                  .toList()
                  .map((metric) => metric.replaceAll("system/", "system.") )
                  .toList();
              if(slicedHistory.any((hist) =>sortedAndDeuplicatedKeys.any((key) => hist.containsKey(key)))){
                validSectionNames.add(section["name"]);
              }
            }

          }
        }else{
          validSectionNames.add(section["name"]);
        }


      }

      // remove sections that are not valid
      //compare if validSectionNames is different from the current sections
      var oldSelNames= sections.map<String>((section) => section["name"]).toSet();
      if(validSectionNames != oldSelNames){
        if(this.mounted && !this.terminated){
          setState(() {
            sections = this.sections.where((section) => validSectionNames.contains(section["name"])).toList();
          });
        }




      }

      var lastUpdate = slicedHistory?.lastOrNull;
      if(lastUpdate != null){
        double? timestamp = lastUpdate["l___timestamp"] ?? lastUpdate["_timestamp"];
        if(timestamp != null){
          this.lastUpdatedDuration.value =DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(timestamp.toInt() * 1000));
        }

      }
    });




    loop(firstLoop: true);

  }


  var paused = false;
  void loop({firstLoop=false}) async {
    if (terminated) return;
    if(Get.arguments == null){
      terminated = true;
      return;
    }

    final run = appController.runs.firstWhere((element) => element["id"] == Get.arguments[0]);
    if(!paused){
      try{

        await appController.loadHistory(run["name"], run["project"]["name"], run["project"]["entityName"],
            allowCache: firstLoop
        );
      }catch(e){
        print(e);
      }
    }else{
      print("(charts) Paused because charts is not visible");
    }

    if (run["state"] == "finished" || run["state"] == "crashed") {
      terminated = true;
      return;
    }


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
    appController.clearHistory();
    historySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    var titleByState = {
      "running": "Running",
      "finished": "Finished",
      "crashed": "Crashed",
    };

    var colorByState = {
      "running": Colors.green,
      "finished": Colors.green,
      "crashed": Colors.red,
    };
    return VisibilityDetector(key:ValueKey("ChartsPage-"+runId),
        onVisibilityChanged: (VisibilityInfo info) {
          if(info.visibleFraction> 0.2){
            paused =false;
          }else{
            paused = true;
          }
        },
    child: DefaultTabController(length: sections.length,
    child:Scaffold(

      appBar: AppBar(

        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text(
                run["displayName"],
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20),
              ),
              Obx(
                ()=>Container(
                  decoration: BoxDecoration(
                      color: colorByState[run["state"]]!
                          .withOpacity(0.90),
                      borderRadius:
                      BorderRadius.circular(4.0)),
                  padding: EdgeInsets.symmetric(
                      vertical: 2.0, horizontal: 8.0),
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
                            color: Colors.white,
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
                              color: Colors.white,
                            ),
                          ),
                      Text(
                        (titleByState[run["state"]]!) + (lastUpdatedDuration.value != null ? " / "+formatDuration(lastUpdatedDuration.value!) : ""),
                        style: TextStyle(
                            fontSize: 10,
                            color:
                            Colors.white,
                            fontWeight: FontWeight.bold),
                      )
                    ],
                  ),
                ),)
            ],)
            ,

          ],
        ),
        bottom:  TabBar(
          isScrollable: sections.length > 4,
          key: ValueKey("tabBar"+sections.length.toString()),
          tabs: [
            ...(sections.map((section) {
              return Tab(text: section["name"], key: ValueKey(section["name"]));
            }).toList())
          ],
        ),
      ),
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          //color: Colors.white,
          child:  Container(
    width: double.infinity,
    child:TabBarView(
        physics: const NeverScrollableScrollPhysics(),
        children: sections.map((section) {
                final sectionWideXAis = section["localPanelSettings"]?["xAxis"];
                var isSystemMetrics = section["name"] == "System";
                return Container(
                  key: ValueKey("sectionView:"+section["name"]),
                  width: double.infinity,
                  child: RefreshIndicator(onRefresh: ()async{
                    await appController.loadCharts();
                    await appController.loadHistory(run["name"], run["project"]["name"], run["project"]["entityName"], forceRefresh: true);
                  }, child: ListView.builder(
                    addAutomaticKeepAlives: true,
                    itemBuilder: (context,index){
                    var panel = section["panels"][index];
                    final xAxis = panel["xAxis"] ?? sectionWideXAis ?? (isSystemMetrics ? "_runtime" : "_step");
                    return  GestureDetector(
                        onTap: (){
                          Get.toNamed("/chartScreen", arguments: [
                            chartId,
                            panel,
                            xAxis,
                            section,
                            isSystemMetrics
                          ]);
                        },
                        child:Container(
                          width: double.infinity,

                          child: AbsorbPointer(
                              absorbing: true,
                              child:ChartComponent(
                                visibilityKey: "ChartComponentVis"+section["name"]+panel["__id__"]+xAxis,
                                isBordered: true,
                                showLastValues: true,
                                runName: run["name"],
                                key: Key("Render"+section["name"]+panel["__id__"]+xAxis),
                                historyWatchable:  isSystemMetrics ? appController.systemMetrics : appController.runHistory,
                                spec: panel,
                                xAxis: xAxis,
                                onPressed: (model,metrics){

                                },
                                lastValuesReport: (lastValues, metrics){
                                  print(lastValues);
                                },
                              )),
                        ));
                  }, itemCount: section["panels"].length,),
                ));
              }).toList()
            ),
          ),
        ))

      ,
      )));
  }
}
