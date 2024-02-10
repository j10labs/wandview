import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:empire/empire.dart';
import 'package:get/get.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:get/get_navigation/src/routes/transitions_type.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wandview/pages/charts.dart';
import 'package:wandview/pages/chartscreen.dart';
import 'package:wandview/pages/login.dart';
import 'package:wandview/pages/runselector.dart';
import 'package:wandview/utils/controllers.dart';
import 'package:wandview/utils/utilities.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // if firebase auth user is not set, then signin with anonymous
  var user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    await FirebaseAuth.instance.signInAnonymously();
    user = FirebaseAuth.instance.currentUser;
  }
  if(await FirebaseMessaging.instance.isSupported()){
    await FirebaseMessaging.instance.requestPermission();
  }

  await FirebaseAnalytics.instance.setUserId(id:user!.uid);
  // await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
  var _prefs = await SharedPreferences.getInstance();
  // check if appVersion (real) is the same as the one in the prefs
  var pInfo = await PackageInfo.fromPlatform();
  var appVersion = pInfo.version;
  if (_prefs.getString("appVersion") != appVersion) {
    // if not, then clear the prefs
    _prefs.clear();
    // and set the new appVersion
    _prefs.setString("appVersion", appVersion);
  }

  _prefs.setString("appSession",generateRandomString() );
  runApp(MyApp());

}

class MyApp extends StatelessWidget {

  MyApp({super.key});
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AppController());
    return GetMaterialApp(
      title: 'WandView',
      defaultTransition: Transition.native,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
          primaryColor: Colors.blueAccent,
          colorScheme: ColorScheme.dark(primary: Colors.blueAccent)
      ),
      routingCallback: (routing) {
        if(routing !=null){
          FirebaseAnalytics.instance.logEvent(name: "routing", parameters: {"routing": routing.current});

        }
      },
      routes: {
        '/': (context) => Scaffold(body: Container(),),
        '/login': (context) =>  AuthPage(),
        '/selector': (context) => HomePage(),
        '/charts': (context) => ChartsPage(),
        '/chartScreen': (context) => ChartScreenPage(),
      },
    );
  }
}

// class MyHomePage extends StatefulWidget {
//   const MyHomePage({super.key, required this.title});
//
//   // This widget is the home page of your application. It is stateful, meaning
//   // that it has a State object (defined below) that contains fields that affect
//   // how it looks.
//
//   // This class is the configuration for the state. It holds the values (in this
//   // case the title) provided by the parent (in this case the App widget) and
//   // used by the build method of the State. Fields in a Widget subclass are
//   // always marked "final".
//
//   final String title;
//
//   @override
//   State<MyHomePage> createState() => _MyHomePageState();
// }
//
// class _MyHomePageState extends State<MyHomePage> {
//   int _counter = 0;
//
//   void _incrementCounter() {
//     setState(() {
//       // This call to setState tells the Flutter framework that something has
//       // changed in this State, which causes it to rerun the build method below
//       // so that the display can reflect the updated values. If we changed
//       // _counter without calling setState(), then the build method would not be
//       // called again, and so nothing would appear to happen.
//       _counter++;
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     // This method is rerun every time setState is called, for instance as done
//     // by the _incrementCounter method above.
//     //
//     // The Flutter framework has been optimized to make rerunning build methods
//     // fast, so that you can just rebuild anything that needs updating rather
//     // than having to individually change instances of widgets.
//     return Scaffold(
//       appBar: AppBar(
//         // TRY THIS: Try changing the color here to a specific color (to
//         // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
//         // change color while the other colors stay the same.
//         backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//         // Here we take the value from the MyHomePage object that was created by
//         // the App.build method, and use it to set our appbar title.
//         title: Text(widget.title),
//       ),
//       body: Center(
//         // Center is a layout widget. It takes a single child and positions it
//         // in the middle of the parent.
//         child: Column(
//           // Column is also a layout widget. It takes a list of children and
//           // arranges them vertically. By default, it sizes itself to fit its
//           // children horizontally, and tries to be as tall as its parent.
//           //
//           // Column has various properties to control how it sizes itself and
//           // how it positions its children. Here we use mainAxisAlignment to
//           // center the children vertically; the main axis here is the vertical
//           // axis because Columns are vertical (the cross axis would be
//           // horizontal).
//           //
//           // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
//           // action in the IDE, or press "p" in the console), to see the
//           // wireframe for each widget.
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: <Widget>[
//             const Text(
//               'You have pushed the button this many times:',
//             ),
//             Text(
//               '$_counter',
//               style: Theme.of(context).textTheme.headlineMedium,
//             ),
//           ],
//         ),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _incrementCounter,
//         tooltip: 'Increment',
//         child: const Icon(Icons.add),
//       ), // This trailing comma makes auto-formatting nicer for build methods.
//     );
//   }
// }
