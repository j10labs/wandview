import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:wandview/components/chart.dart';

import '../utils/controllers.dart';
class ChartsPage extends StatefulWidget {
  ChartsPage({super.key});

  @override
  _ChartsPageState createState() => _ChartsPageState();
}

class _ChartsPageState extends State<ChartsPage> {
  final appController = Get.find<AppController>();
  bool terminated = false;
  var runId = Get.arguments[0];
  @override
  void initState() {
    super.initState();
    appController.clearHistory();
    loop(firstLoop: true);
  }

  void loop({firstLoop=false}) async {
    if (terminated) return;
    if(Get.arguments == null){
      terminated = true;
      return;
    }

    final run = appController.runs.firstWhere((element) => element["id"] == Get.arguments[0]);

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
    appController.clearHistory();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final  chartId = Get.arguments[0];
    final run = appController.runs.firstWhere((element) => element["id"] == chartId);
    final chartInfo  = appController.chartInfo[run["id"]][0];
    final spec = chartInfo["spec"];
    final panelBankConfig = spec["panelBankConfig"];
    final List<dynamic> sections = panelBankConfig["sections"];
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
    return DefaultTabController(length: sections.length,
    child:Scaffold(

      appBar: AppBar(

        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              run["displayName"],
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20),
            ),
            Container(
              margin: EdgeInsets.only(left: 10),
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
                    titleByState[run["state"]]!,
                    style: TextStyle(
                        fontSize: 10,
                        color:
                        Colors.white,
                        fontWeight: FontWeight.bold),
                  )
                ],
              ),
            )
          ],
        ),
        bottom:  TabBar(
          tabs: [
            ...(sections.map((section) {
              return Tab(text: section["name"]);
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
        children: [
              ...(sections.map((section) {
                final sectionWideXAis = section["localPanelSettings"]?["xAxis"];
                var isSystemMetrics = section["name"] == "System";
                return Container(
                  width: double.infinity,
                  child: RefreshIndicator(onRefresh: ()async{
                    await appController.loadCharts();
                    await appController.loadHistory(run["name"], run["project"]["name"], run["project"]["entityName"]);
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
                                isBordered: true,
                                runName: run["name"],
                                key: Key(section["name"]+panel["__id__"]+xAxis),
                                historyWatchable: isSystemMetrics ?  appController.systemMetrics:appController.runHistory,
                                spec: panel,
                                xAxis: xAxis,
                                onPressed: (model){

                                },
                                lastValuesReport: (lastValues){
                                  print(lastValues);
                                },
                              )),
                        ));
                  }, itemCount: section["panels"].length,),
                ));
              }).toList())
            ]),
          ),
        ))

      ,
      ));
  }
}
