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
        color: Color.fromARGB(250, 3, 54, 183),
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
                        child:   TextField(
                          onChanged: (value){
                            appController.hostChange(value);
                          },
                          decoration: InputDecoration.collapsed(
                            hintText: 'Host (Domain name)',
                            fillColor:  appController.isAuthenticating.value ? Colors.grey.shade300 : Colors.white,
                            filled: true,


                          ),
                          readOnly: appController.isAuthenticating.value,
                          style: TextStyle(

                            fontSize: 23,


                          ),

                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color:  appController.isAuthenticating.value ? Colors.grey.shade300 : Colors.white,
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),

                      ),
                      SizedBox(height: 30,),
                      Container(
                        child:   TextField(
                          onChanged: (value){
                            appController.apiKeyChange(value);
                          },
                          decoration: InputDecoration.collapsed(
                            hintText: 'API Key',
                            fillColor: appController.isAuthenticating.value ? Colors.grey.shade300 : Colors.white,
                            filled: true,


                          ),
                          style: TextStyle(

                            fontSize: 23,


                          ),
                          readOnly: appController.isAuthenticating.value,

                        ),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: appController.isAuthenticating.value ? Colors.grey.shade300 : Colors.white
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),

                      ),

                    ],


                  ),),
                  SizedBox(height: 40,),
                  GestureDetector(
                    onTap: (){
                      if(!appController.isAuthenticating.value){
                        appController.authenticate();
                      }
                    },
                    child:  Container(
                      padding: EdgeInsets.symmetric(horizontal: 35, vertical: 12),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: appController.isAuthenticating.value ? Colors.grey.shade300 : Colors.white
                      ),
                      child: Text("Authenticate", style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),),

                    ),
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
            color: Color.fromARGB(250, 3, 54, 183),
            alignment: Alignment.center,
            child: CircularProgressIndicator(color: Colors.white,),
          ) : Container(),
        ],),
    )),

    );
  }

}
