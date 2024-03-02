import 'dart:convert';
import 'dart:ffi';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:get/get.dart';
import 'package:graphql/client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wandview/utils/utilities.dart';
class AuthObject {
  final String host;
  final String apiKey;
  final bool authenticated;
  AuthObject(this.host, this.apiKey, this.authenticated);
}

List<Map<String,dynamic>> decodeJsonList(List<dynamic> jsonList) {
  return jsonList.map<Map<String,dynamic>>((e) => jsonDecode(e) as Map<String,dynamic>).toList();
}
class UserProfile {
  final String username;
  final String email;
  final String name;
  final String photoUrl;
  UserProfile(this.username, this.name, this.email, this.photoUrl);
}
class AppController extends GetxController {
  final  authObject=(null as AuthObject?).obs;
  final userProfile=(null as UserProfile?).obs;
  final projects = [].obs;
  final runs = [].obs;
  final isAuthenticating = false.obs;
  final authError = "".obs;
  final selectedProject = "all".obs;
  final runHistory = <Map<String,dynamic>>[].obs;
  final systemMetrics = <Map<String,dynamic>>[].obs;
  final tRunHistory =  <Map<String,dynamic>>[].obs;
  final tSystemMetrics =  <Map<String,dynamic>>[].obs;
  final chartInfo = {}.obs;
  late SharedPreferences prefs;
  late GraphQLClient client;

  @override
  void onInit() async {
    // TODO: implement onInit
    super.onInit();

    authObject.reactive.addListener(() {
      selectedProject.value="all";
      runs.value=[];
      runHistory.value=[];
      systemMetrics.value=[];
    });
    //load authObject from localStorage
    //if not found, redirect to login page
    var _prefs= await SharedPreferences.getInstance();
    prefs=_prefs;
    if(prefs.containsKey("authObject")){
      var _authObject=prefs.getStringList("authObject")!;
      var authenticated= _authObject[2]=="true";
      authObject.value=AuthObject(_authObject[0], _authObject[1], authenticated);
    }else{
    }
    var authResult = await authenticate();
    if(authResult == "login"){
      Get.offAndToNamed("/login");
    }



  }

  String authorizationToken(){
    var unameAndPass = ["api", authObject.value!.apiKey];
    var generatedToken ="Basic ${base64Encode(utf8.encode(unameAndPass.join(':')))}";
    return generatedToken;
  }

  authenticate() async {
    if (authObject.value==null) return "login";
    //check if authObject is valid, host and apiKey are not empty, and host is a valid domain name
    if (authObject.value!.host.isEmpty || authObject.value!.apiKey.isEmpty) {
      authError.value = "Invalid host or API key";
      return "login";
    }
    var authObjectHost = authObject.value!.host;
    if (!GetUtils.isURL("https://"+authObjectHost)) {

      authObjectHost = "api.wandb.ai";
    }
    isAuthenticating.value=true;

    final _httpLink = HttpLink(
      "https://"+authObjectHost+"/graphql",
    );
    var unameAndPass = ["api", authObject.value!.apiKey];
    var generatedToken ="Basic ${base64Encode(utf8.encode(unameAndPass.join(':')))}";
    print(generatedToken);
    final _authLink = AuthLink(
      getToken: () async => generatedToken,
    );
    final _link = _authLink.concat(_httpLink);


    final GraphQLClient client = GraphQLClient(
      /// **NOTE** The default store is the InMemoryStore, which does NOT persist to disk
      cache: GraphQLCache(),
      link: _link,
    );
    this.client=client;
    final QueryOptions options = QueryOptions(
      document: gql(r'''
       query Viewer{
            viewer {
                id
                username
                name
                email
                photoUrl
            }
       }      
    '''),
    );
    final QueryResult result = await client.query(options);

    if (result.hasException) {
      authError.value=result.exception.toString();
      isAuthenticating.value=false;
      return "login";
    }
    print(["Auth Result=", result.data]);
    if(result.data?["viewer"]==null){
      authError.value="Invalid API key";
      isAuthenticating.value=false;
      return "login";
    }
    //save authObject to localStorage
    prefs.setStringList("authObject", [authObject.value!.host, authObject.value!.apiKey, "true"]);

    userProfile.value=UserProfile(
        result.data?["viewer"]["username"],
        result.data?["viewer"]["name"],
        result.data?["viewer"]["email"],
        result.data?["viewer"]["photoUrl"]);
    print(result.data);
    projects.value=[];

    runHistory.value = [];
    systemMetrics.value = [];
    await loadRunsAndProjects();
    isAuthenticating.value=false;

    Get.offAndToNamed("/selector");

    // await Future.delayed(Duration(seconds: 4));
    // isAuthenticating.value=false;

  }
  clearHistory(){
    runHistory.value=[];
    systemMetrics.value=[];
  }

  compareSimiliarity(List<dynamic> a, List<dynamic> b){
    // return false;
    var lastA = a.lastOrNull;
    var lastB = b.lastOrNull;

    if(lastA == null || lastB == null) return false;
    //if(lastA.keys.length != lastB.keys.length) return false;
    //if (a.length != b.length) return false;
    for(var key in lastB.keys){
      var lastAComp = lastA["l__"+key] ?? lastA[key];
      if((lastAComp != null && lastB[key] != null)){
        if(key == "_step" || key == "_runtime"){
          var isSimiliar = lastAComp == lastB[key];
          print("Comparing $key : $lastAComp and ${lastB[key]}, similiar=$isSimiliar");
          if(!isSimiliar) return false;
        }


      }

    }
    return true;
  }

  void refreshLastSeen(runId, List<Map<String,dynamic>> finalRunHistory){
    var fn = (finalRunHistory.map((e)=>e["_step"] ?? e["_runtime"])).lastOrNull;
    double? lastLoadedStep =  (fn != null) ? fn.toDouble() : null;
    var appSessionId = prefs.getString("appSession")!;

    var storedLastSeenStep = prefs.getDouble("$runId:lastSeenStep");
    var sessionLastSeenStep =  prefs.getDouble("$appSessionId:$runId:lastSeenStep");
    double? absoluteLastSeenStep;
    if (storedLastSeenStep != null){
      absoluteLastSeenStep = storedLastSeenStep;
    }else if(lastLoadedStep != null){
      absoluteLastSeenStep = lastLoadedStep;
    }
    if(lastLoadedStep != null ){
      prefs.setDouble("$runId:lastSeenStep", lastLoadedStep);
    }

    if(sessionLastSeenStep == null && absoluteLastSeenStep!= null && (lastLoadedStep != storedLastSeenStep)){
      prefs.setDouble("$appSessionId:$runId:lastSeenStep", absoluteLastSeenStep);
    }
  }


  var fileQueryCache = <String, String>{};

  Future<Map<String, String>> fileQuery(
      {required String runId,
        required String projectName,
        required String entityName,
        required List<String> filenames}) async {

    final QueryOptions options = QueryOptions(
        document: gql(r'''
       query ($runId: String!, $filenames: [String]!, $projectName: String!, $entityName: String!) {
          project(entityName: $entityName, name: $projectName) {
        id
        run(name: $runId) {
          id
          files(names: $filenames) {
            edges {
              node {
                id
                name
                directUrl 
                url(upload: false)
                md5
                sizeBytes
                __typename
              }
              __typename
            }
            __typename
          }
          __typename
        }
        __typename
        }


         
       }     
        
    '''),
        variables: {
          "runId": runId,
          "projectName": projectName,
          "entityName": entityName,
          "filenames": filenames
        },
        fetchPolicy: FetchPolicy.cacheAndNetwork
    );
    // check if all filenames are in the cache
    var allExist = filenames.every((element) => fileQueryCache.containsKey(element));
    if(allExist){
      return fileQueryCache;
    }

    var result = await client.query(options);


    var fileMap = <String, String>{};
    var files = result.data?["project"]["run"]["files"]["edges"];
    for (var file in files){
      var node = file["node"];
      fileMap[node["name"]] = node["directUrl"] as String;
      fileQueryCache[node["name"]] = node["directUrl"] as String;
    }
    return fileMap;

  }
  queryLastStep(runId, projectName, entityName) async {
    final QueryOptions options = QueryOptions(
      document: gql(r'''
       query ($runId: String!, $projectName: String!, $entityName: String!) {
         
         project (name:$projectName, entityName: $entityName ){
         run(name: $runId) {
         historyKeys
         }
         }
         
       }     
        
    '''),
      variables: {
        "runId": runId,
        "projectName": projectName,
        "entityName": entityName
      },
      fetchPolicy: FetchPolicy.cacheAndNetwork
    );

    var result = await client.query(options);
    try{
      var lastStep = (result.data?["project"]["run"]["historyKeys"]["lastStep"] as num? ) ?? 0;
      return (max(0,lastStep- 50000), lastStep+1000);
    }catch(e){
      return (0, 50000);
    }


  }

  loadHistory(runId, projectName, entityName, {onProject=false, allowCache=false, List<Map<String,dynamic>>? previousMetrics=null, List<Map<String,dynamic>>? previousSystemMetrics=null, bool forceRefresh=false})async{
    //return (<Map<String,dynamic>>[],<Map<String,dynamic>>[],false);
    if(chartInfo.isEmpty){
      await loadCharts();
    }
    var finalRunHistory = (onProject)? (previousMetrics ?? []) :  runHistory.value;
    var finalSystemMetrics = (onProject)? (previousSystemMetrics ?? []) :  systemMetrics.value;
    var cacheData= false;
    if(allowCache && (finalRunHistory.isEmpty)){
      var cachedComputedHistory = prefs.getString(runId+"history");
      if (cachedComputedHistory != null){
        List<Map<String,dynamic>> cachedHistory = jsonDecode(cachedComputedHistory).map<Map<String,dynamic>>((e)=>e as Map<String,dynamic>).toList();
        finalRunHistory = cachedHistory;
        cacheData = true;
      }
      var cachedComputedSystemMetrics = prefs.getString(runId+"systemMetrics");
      if (cachedComputedSystemMetrics != null){
        List<Map<String,dynamic>> cachedSystemMetrics = jsonDecode(cachedComputedSystemMetrics).map<Map<String,dynamic>>((e)=>e as Map<String,dynamic>).toList();
        finalSystemMetrics = cachedSystemMetrics;
        cacheData = true;
      }
    }




    if(cacheData && (finalRunHistory.isNotEmpty)){
      if(onProject){
        return (finalRunHistory, finalSystemMetrics, true);
      }
      runHistory.value =finalRunHistory;
      systemMetrics.value = finalSystemMetrics;
    }

    var (qLastStep, qTotalLimit) = await queryLastStep(runId, projectName, entityName);

    final QueryOptions options = QueryOptions(
      document: gql(r'''
       query ($runId: String!, $projectName: String!, $entityName: String!, $qLastStep: Int64!, $qTotalLimit: Int64!) {
         
         project (name:$projectName, entityName: $entityName ){
         run(name: $runId) {
         history(minStep: $qLastStep, maxStep: $qTotalLimit)
         events
         systemMetrics
         summaryMetrics
         historyKeys
         historyLineCount
         historyTail
         
         
         id
         name
         
         }
         }
         
       }     
        
    '''),
      variables: {
        "runId": runId,
        "projectName": projectName,
        "entityName": entityName,
        "qLastStep": qLastStep,
        "qTotalLimit": qTotalLimit
      },
      fetchPolicy: allowCache ?FetchPolicy.cacheFirst : FetchPolicy.networkOnly,
      cacheRereadPolicy: allowCache ? CacheRereadPolicy.mergeOptimistic : CacheRereadPolicy.ignoreAll
    );




    final QueryResult result = await client.query(options);



    result.parserFn = (response) {
      //parse it to projects and runs, and interlock them
      var history = response["project"]["run"]["history"] as List;
      var events = response["project"]["run"]["events"] as List;
      var lastStep = response["project"]["run"]["historyKeys"]["lastStep"] as num?;

      return [history.toList(),
        events.toList(),
        lastStep];
    };
    if(result.hasException){
      print("Something went wrong!");
      print(result.exception);
      return;
    }
    var [List<dynamic> _queriedHistory, List<dynamic> _queriedSystemMetrics, num? lastStep] = result.parsedData as List<dynamic>;
    print("Downloaded ${_queriedHistory.length} Histories");
    print("Downloaded ${_queriedSystemMetrics.length} System Metrics");

    var queriedHistory = await compute(decodeJsonList, _queriedHistory);
    var queriedSystemMetrics = await compute(decodeJsonList, _queriedSystemMetrics);
    //check if runHistory is the same as queriedHistory


    var runHistoryIsSimiliar = compareSimiliarity(finalRunHistory, queriedHistory);
    var systemMetricsIsSimiliar = compareSimiliarity(finalSystemMetrics, queriedSystemMetrics);



    var shouldVibrate = false;
    if (!runHistoryIsSimiliar || forceRefresh) {
      if(!allowCache && queriedHistory.length > 0){
        // vibrate the phone

        shouldVibrate = true;
      }
      print("Run History is not similiar");
      var formattedHistory =(await compute(isolatedRun,queriedHistory)) as List<Map<String,dynamic>>;

      prefs.setString(runId+"history", jsonEncode(formattedHistory));
      finalRunHistory = formattedHistory;

    } else {
      print("Run History is similiar");
    }
    if (!systemMetricsIsSimiliar || forceRefresh) {
      // if (!allowCache){
      //   // vibrate the phone
      //   shouldVibrate = true;
      // }
      print("System Metrics is not similiar");
      var formattedSystemMetrics = (await compute(isolatedRun,queriedSystemMetrics)) as List<Map<String,dynamic>>;

      prefs.setString(runId+"systemMetrics", jsonEncode(formattedSystemMetrics));
      finalSystemMetrics = formattedSystemMetrics ;
      if(!onProject){
        systemMetrics.value = finalSystemMetrics;
      }
    } else {
      print("System Metrics is similiar");
    }

    if(shouldVibrate){
      if (await Vibrate.canVibrate) {
        Vibrate.vibrate();
      }
    }
    if(!runHistoryIsSimiliar || allowCache){
      refreshLastSeen(runId, finalRunHistory);
    }


    if(onProject){
      return (finalRunHistory, finalSystemMetrics, !runHistoryIsSimiliar || !systemMetricsIsSimiliar);
    }else{
      if(!runHistoryIsSimiliar){
        runHistory.value = finalRunHistory;
      }
      if (!systemMetricsIsSimiliar){
        systemMetrics.value = finalSystemMetrics;
      }
    }


  }
  loadCharts() async {
    final QueryOptions options = QueryOptions(
      document: gql(r'''
       query {
         viewer {
         projects (order: "-createdAt") {
              pageInfo {
                hasNextPage
                  hasPreviousPage
                  startCursor
                  endCursor
              }
              edges {
              
              node {
                name  
                id
               
                createdAt
                entityName
                entityId
                ndbId
                userId

       
                 
              }              
              }
            }
              views {
                    pageInfo {
                  hasNextPage
                    hasPreviousPage
                    startCursor
                    endCursor
                    }
                    edges {
                    node {
                     type
                    description 
                    locked
                    spec
                    displayName
                    createdAt
                    createdUsing
                    projectId
                    entityName
                    
                    project{
                    id
                    name
                    }
                    }                  
                    }
                  }
              
         }
       }      
    '''),
    );
    final QueryResult result = await client.query(options);
    result.parserFn = (response) {
      //parse it to projects and runs, and interlock them
      var projects = response["viewer"]["projects"]["edges"];

      var historyAndCharts = <String, dynamic>{};
      for (var project in projects) {
        var projectData = project["node"];
        var views = response["viewer"]["views"]["edges"].where((element) => (element["node"]["project"]?["id"] ==projectData["id"]));

        var historyAndChartsForRun = [];
        for (var view in views) {
          var viewData = view["node"];
          var specJsonString =  viewData["spec"];
          var spec = jsonDecode(specJsonString);
          var type = viewData["type"];
          var description = viewData["description"];
          var displayName = viewData["displayName"];
          var createdAt = viewData["createdAt"];
          var createdUsing = viewData["createdUsing"];
          var locked = viewData["locked"];
          if (spec?["ref"]?["type"] == "run-view") {
            historyAndChartsForRun.add({
              "type": type,
              "description": description,
              "displayName": displayName,
              "createdAt": createdAt,
              "createdUsing": createdUsing,
              "locked": locked,
              "spec": spec
            });
          }
        }
        historyAndCharts[projectData["id"]] = historyAndChartsForRun;
      }
      return historyAndCharts;
    };
    var queriedHistoryAndCharts = result.parsedData;
    chartInfo.value = queriedHistoryAndCharts as Map<String, dynamic>;
  }

  loadRunsAndProjects() async {

    final QueryOptions options = QueryOptions(
      document: gql(r'''
       query{
       viewer{
       
         projects (order: "-createdAt") {
              pageInfo {
                hasNextPage
                  hasPreviousPage
                  startCursor
                  endCursor
              }
              edges {
              
              node {
name  
id
createdAt

       
                 
              }              
              }
            }
            runs (order: "-createdAt") {
              pageInfo {
                hasNextPage
                  hasPreviousPage
                  startCursor
                  endCursor
              }
              edges {
                node {
                  id
                  projectId
                  
                  project {
                    name
                    id
                    entityName
                  }
                  name
                  historyLineCount
                  displayName
                  sweepName
                  
                  createdAt
                  state
                }
              }
            }
              
       }
          
       }      
    ''')
    );
    final QueryResult result = await client.query(options);
    result.parserFn = (response) {
      //parse it to projects and runs, and interlock them
      var projects = response["viewer"]["projects"]["edges"];
      var runs = List<dynamic>.of(response["viewer"]["runs"]["edges"]);
      var allProjects = [];

      allProjects.add({
        "name": "All Projects",
        "id": "all",
        "runs": runs.map((e) => e["node"]).toList()
      });
      for (var project in projects) {
        var projectData = project["node"];
        var runsForProject = [];
        for (var run in runs) {
          var runData = run["node"];
          if (runData["project"]["id"] == projectData["id"]) {
            runsForProject.add(runData);
          }
        }
        projectData["runs"] = runsForProject;
        allProjects.add(projectData);
      }


      return [allProjects,runs.map((e) => e["node"]).toList()];
    };
    var [_projects, _runs] = result.parsedData as List<dynamic>;
    // if selectedProject is not "all", and it is not in the list of projects, set it to "all"
    if(selectedProject.value == "all"){
      var selectedProjectDefault = prefs.getString("defaultSelectedProject") ?? "all";
      selectedProject.value = selectedProjectDefault;
    }
    if (selectedProject.value != "all") {
      var found = false;
      for (var project in _projects) {
        if (project["id"] == selectedProject.value) {
          found = true;
          break;
        }
      }
      if (!found) {
        selectedProject.value = "all";
      }
    }
    projects.value = _projects;
    runs.value = _runs;
    await loadCharts();
  }



  void selectProject (projectId){
    prefs.setString("defaultSelectedProject", projectId);
    selectedProject.value=projectId;
  }

  void hostChange (String host){
    authObject.value ??= AuthObject(host, "", false);
    authObject.value=AuthObject(host,
        authObject.value!.apiKey, false);
  }
  void apiKeyChange (String apiKey){
    if(authObject.value==null) {
      authObject.value=AuthObject("api.wandb.ai", apiKey, false);
    }
    authObject.value=AuthObject(authObject.value!.host,
        apiKey, false);
  }

  void logout() async {
    prefs.remove("authObject");
    authObject.value= null;
    userProfile.value=null;
     Get.offAndToNamed("/login");

  }




}

// ALWAYS remember to pass the `Type` you used to register your controller!
