import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';

import '../utils/controllers.dart';

class HomePage extends StatelessWidget {
  HomePage({super.key});

  final appController = Get.find<AppController>();

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Scaffold(
        body: Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white,
      child: Obx(()=>Column(
        children: [
        Expanded(flex:1,
            child:
            SafeArea(child: Container(
                width: double.infinity,
                child: LayoutBuilder(
                  builder: (context, constraint) {
                    return    RefreshIndicator(
                        triggerMode: RefreshIndicatorTriggerMode.anywhere,

                        onRefresh: () async {
                          await appController.loadRunsAndProjects();
                        },
                        child: SingleChildScrollView(
                            physics: AlwaysScrollableScrollPhysics(),
                            child: Container(
                              width: double.infinity,
                              height: constraint.maxHeight,
                              child: Column(
                                children: [
                                  Container(child:
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,

                                    child: Obx(()=>Row(

                                      children: [
                                        ...appController.projects.map((project)  {
                                          return Container(
                                            key: Key(project["id"]),
                                            margin: EdgeInsets.symmetric(horizontal: 5, vertical: 15),
                                            child: ElevatedButton(
                                              onPressed: () {
                                                appController.selectProject(project["id"]);
                                              },
                                              child: Text(project["name"]),
                                              style: ButtonStyle(
                                                backgroundColor: MaterialStateProperty.all(appController.selectedProject.value==project["id"] ? Color.fromARGB(250, 3, 54, 183) : Colors.grey.shade100),
                                                foregroundColor: MaterialStateProperty.all(appController.selectedProject.value==project["id"] ? Colors.white : Colors.black),
                                              ),
                                            ),
                                          );
                                        }).toList()
                                      ],
                                    )),
                                  ),
                                  width: double.infinity,
                                  ),
                                  Expanded(child: Container(
                                    child: Obx(()=>ListView(
                                      children: [
                                        ...appController.projects.firstWhere((element) =>
                                        element["id"]==appController.selectedProject.value)["runs"]
                                        .map((run)  {
                                          return GestureDetector(
                                              onTap: (){
                                                Get.toNamed("/charts", arguments:[ run["id"]]);
                                              },
                                              child: Container(
                                            key: Key(run["id"]),
                                            margin: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                                            decoration: BoxDecoration(
                                              border: Border.all(color: Colors.grey.shade300),
                                              borderRadius: BorderRadius.circular(5),
                                            ),
                                            child: Row(
                                              children: [
                                                Text(run["displayName"]),
                                                Expanded(child: Container()),
                                                if(run["state"]=="running") Container(
                                                  margin: EdgeInsets.only(right: 10),
                                                  width: 10,
                                                  height: 10,
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius: BorderRadius.circular(5),
                                                  ),
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    value: run["progress"],
                                                    color: Colors.green,
                                                  )
                                                )
                                                else if (run["state"] == "crashed") Container(
                                                  margin: EdgeInsets.only(right: 10),

                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                  ),
                                                  child: Icon(Icons.error, size: 15, color: Colors.red,),
                                                )
                                                else if (run["state"] == "finished") Container(
                                                  margin: EdgeInsets.only(right: 10),

                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                  ),
                                                    child: Icon(Icons.check, size: 15, color: Colors.green,),

                                                  )
                                              ],
                                            )
                                          ));
                                        }).toList()
                                      ],
                                    )),
                                  ))

                                ],
                              ),
                            )
                        ));
                  },
                )),)

        ),
          // Expanded(
          //     flex: 1,
          //     child: Container(
          //       width: double.infinity,
          //       color: Colors.blue,
          //       child: ,
          //     )),
          appController.userProfile.value != null ? Container(
            color: Color.fromARGB(250, 3, 54, 183),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.network(
                  appController.userProfile.value!.photoUrl,
                  width: 40,
                  height: 40,
                ),
                SizedBox(
                  width: 10,
                ),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appController.userProfile.value!.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16,
                          color: Colors.white
                      ),
                    ),
                    Text(appController.userProfile.value!.email,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12
                      ),
                    ),
                  ],
                ), flex: 1,),
                IconButton(
                  onPressed: () {
                    appController.logout();
                  },
                  icon: Icon(Icons.logout, color: Color.fromARGB(250, 3, 54, 183),),
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all(Colors.white),
                    foregroundColor: MaterialStateProperty.all(Color.fromARGB(250, 3, 54, 183)),
                  )
                )
              ],
            ),
          ) : Container(),
        ],
      ),
    )));
  }
}
