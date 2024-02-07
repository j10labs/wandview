/**
 * generate flutter component for charts,
 */
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:wandview/utils/controllers.dart';
import 'package:empire/empire.dart';

class AuthPage extends StatelessWidget {
  final appController = Get.find<AppController>();
  AuthPage({ super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Scaffold(
      body:  Obx(()=>Container(
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(vertical:20, horizontal: 30),
        child: Stack(

          alignment: Alignment.center,
          children: [
          SingleChildScrollView( child:
          Container(
              width: 300,
              child:Column(

                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  SvgPicture.asset(
                    "assets/logo.svg",
                    width: 170,
                  ),
                  SizedBox(height: 60,),
                  Container(child:  Column(

                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color:  appController.isAuthenticating.value ? Colors.grey.shade300 : Colors.white,
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                        child:   TextFormField(
                          onChanged: (value){
                            appController.hostChange(value);
                          },
                          initialValue: "api.wandb.ai",
                          autofillHints: ["api.wandb.ai"],
                          enableSuggestions: true,
                          textCapitalization: TextCapitalization.none,
                          decoration: InputDecoration.collapsed(
                            hintText: 'api.wandb.ai',
                            fillColor:  appController.isAuthenticating.value ? Colors.grey.shade300 : Colors.white,

                            filled: true,

                          ),
                          readOnly: appController.isAuthenticating.value,
                          style: TextStyle(

                            fontSize: 23,
                            color: Colors.grey.shade900


                          ),


                        ),

                      ),
                      SizedBox(height: 30,),
                      Container(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: appController.isAuthenticating.value ? Colors.grey.shade300 : Colors.white
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                        child:   TextField(
                          onChanged: (value){
                            appController.apiKeyChange(value);
                          },
                          enableSuggestions: true,
                          textCapitalization: TextCapitalization.none,
                          decoration: InputDecoration.collapsed(
                            hintText: 'API Key',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                            ),
                            fillColor: appController.isAuthenticating.value ? Colors.grey.shade300 : Colors.white,
                            filled: true,


                          ),
                          style: TextStyle(

                            fontSize: 23,
                              color: Colors.grey.shade900

                          ),
                          readOnly: appController.isAuthenticating.value,

                        ),

                      ),

                    ],


                  ),),
                  SizedBox(height: 20,),
                  Container(
                    child: Text("* Authentiation and data is only sent to your wandb server", style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade300,
                    ),),
                    alignment: Alignment.bottomLeft,
                  ),
                  SizedBox(height: 40,),

                  ElevatedButton(
                    // decoration: BoxDecoration(
                    //     borderRadius: BorderRadius.circular(10),
                    //     color: appController.isAuthenticating.value ? Colors.grey.shade300 : Colors.white
                    // ),
                    style: ButtonStyle(
                      backgroundColor: MaterialStatePropertyAll(Colors.blueAccent),
                      foregroundColor: MaterialStatePropertyAll(Colors.white)
                    ),

                    onPressed: () {
                      if(!appController.isAuthenticating.value){
                        appController.authenticate();
                      }
                    },
                    child: Text("Authenticate", style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.normal,
                        color: Colors.white
                    ),),

                  ),
                  SizedBox(height: 20,),
                  (appController.authError.value.length < 1) ?Container(): Container(
                    width: double.infinity,
                    alignment: Alignment.center,
                    child: Text(appController.authError.value, style: TextStyle(
                      fontSize: 14,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,

                    ),),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      color: Colors.white,
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  )

                ],

              ))),
          appController.isAuthenticating.value ? Container(
            color:  Color(0xFF1C1B1F),
            alignment: Alignment.center,
            child: CircularProgressIndicator(color: Colors.white,),
          ) : Container(),
        ],),
    )),

    );
  }

}
