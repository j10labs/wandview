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

  @override
  void initState() {
    super.initState();
    loop();
  }

  void loop() async {
    if (terminated) return;
    final run = appController.runs.firstWhere((element) => element["id"] == Get.arguments[0]);
    await Future.delayed(Duration(seconds: 1));
    await appController.loadHistory(run["name"], run["project"]["name"], run["project"]["entityName"]);
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
    return DefaultTabController(length: sections.length,
    child:Scaffold(
      appBar: AppBar(
        title: Text(run["displayName"] + " (" + run["state"] + ")"),
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
          color: Colors.white,
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
                  }, child: ListView.builder(itemBuilder: (context,index){
                    var panel = section["panels"][index];
                    final xAxis = panel["xAxis"] ?? sectionWideXAis ?? (isSystemMetrics ? "_runtime" : "_step");
                    return Obx(()=>GestureDetector(
                        onTap: (){
                          Get.toNamed("/chartScreen");
                        },
                        child:Container(
                          width: double.infinity,
                          margin: EdgeInsets.all(10),
                          child: ChartComponent(
                            key: Key(section["name"]+panel["__id__"]+xAxis),
                            history: isSystemMetrics ?  appController.systemMetrics.value:appController.runHistory.value,
                            spec: panel,
                            xAxis: xAxis,
                            onPressed: (){
                              Get.toNamed("/chartScreen", arguments: [
                                chartId,
                                panel,
                                xAxis,
                                section,
                                isSystemMetrics
                              ]);
                            },
                          ),
                        )));
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
