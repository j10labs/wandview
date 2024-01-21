import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:wandview/components/chart.dart';

import '../utils/controllers.dart';
class ChartScreenPage extends StatefulWidget {
  ChartScreenPage({super.key});

  @override
  _ChartScreenPageState createState() => _ChartScreenPageState();
}

class _ChartScreenPageState extends State<ChartScreenPage> {
  final appController = Get.find<AppController>();
  bool terminated = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
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
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    appController.clearHistory();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final [ chartId, panel,
    xAxis,
    section,
    isSystemMetrics ] = Get.arguments;

    return Scaffold(
      body: SafeArea(child: Container(child:
      Obx(()=>
      ChartComponent(
        key: Key(section["name"]+panel["__id__"]+xAxis),
        history: isSystemMetrics ?  appController.systemMetrics.value:appController.runHistory.value,
        spec: panel,
        xAxis: xAxis, onPressed: (){},
        maxHistoryLength: 100000,
      )),
        width: double.infinity,
        height: double.infinity,
      ),),
    );
  }
}
