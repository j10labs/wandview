import 'dart:convert';
import 'dart:ffi';

import 'package:get/get.dart';
import 'package:graphql/client.dart';
import 'package:shared_preferences/shared_preferences.dart';
class AuthObject {
  final String host;
  final String apiKey;
  final bool authenticated;
  AuthObject(this.host, this.apiKey, this.authenticated);
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
  final runHistory = [].obs;
  final systemMetrics = [].obs;
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



  authenticate() async {
    if (authObject.value==null) return "login";
    //check if authObject is valid, host and apiKey are not empty, and host is a valid domain name
    if (authObject.value!.host.isEmpty || authObject.value!.apiKey.isEmpty) {
      authError.value = "Invalid host or API key";
      return "login";
    }
    if (!GetUtils.isURL("https://"+authObject.value!.host)) {
        authError.value = "Host must be a domain name";
        return "login";
    }
    isAuthenticating.value=true;
    final _httpLink = HttpLink(
      "https://"+authObject.value!.host+"/graphql",
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

    await loadRunsAndProjects();
    isAuthenticating.value=false;
    Get.offAndToNamed("/selector");

    // await Future.delayed(Duration(seconds: 4));
    // isAuthenticating.value=false;

  }
  clearHistory(){
    runHistory.value=[];
  }
  loadHistory(runId, projectName, entityName)async{
    final QueryOptions options = QueryOptions(
      document: gql(r'''
       query ($runId: String!, $projectName: String!, $entityName: String!) {
         
         project (name:$projectName, entityName: $entityName ){
         run(name: $runId) {
         history
         events
         systemMetrics 
         summaryMetrics
         
         
         id
         name
         
         }
         }
         
       }     
        
    '''),
      variables: {
        "runId": runId,
        "projectName": projectName,
        "entityName": entityName
      }
    );


    final QueryResult result = await client.query(options);
    result.parserFn = (response) {
      //parse it to projects and runs, and interlock them
      var history = response["project"]["run"]["history"] as List;
      var events = response["project"]["run"]["events"] as List;

      return [history.map((e) {
        return jsonDecode(e);
      }).toList(), events.map((e) {
        return jsonDecode(e);
      }).toList()];
    };
    var [queriedHistory, queriedSystemMetrics] = result.parsedData as List<dynamic>;
    //check if runHistory is the same as queriedHistory
    if (runHistory.value.length == queriedHistory.length) {
      var same = true;
      for (var i = 0; i < runHistory.value.length; i++) {
        //match each item, each key
        var item = runHistory.value[i];
        var queriedItem = queriedHistory[i];
        for (var key in item.keys) {
          if (item[key] != queriedItem[key]) {
            same = false;
            break;
          }
        }
      }
      if (!same) {
        runHistory.value = queriedHistory ;
      }
    } else {
      runHistory.value = queriedHistory ;
    }

    if (systemMetrics.value.length == queriedSystemMetrics.length) {
      var same = true;
      for (var i = 0; i < systemMetrics.value.length; i++) {
        //match each item, each key
        var item = systemMetrics.value[i];
        var queriedItem = queriedSystemMetrics[i];
        for (var key in item.keys) {
          if (item[key] != queriedItem[key]) {
            same = false;
            break;
          }
        }
      }
      if (!same) {
        systemMetrics.value = queriedSystemMetrics ;
      }
    } else {
      systemMetrics.value = queriedSystemMetrics ;
    }



  }
  loadCharts() async {
    final QueryOptions options = QueryOptions(
      document: gql(r'''
       query {
         viewer {
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
                  name
                  
                  
                }
              }
            }
            
            views{
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
      var runs = List<dynamic>.of(response["viewer"]["runs"]["edges"]);
      var views = List<dynamic>.of(response["viewer"]["views"]["edges"]);
      var historyAndCharts = <String, dynamic>{};
      for (var run in runs) {
        var runData = run["node"];
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
        historyAndCharts[runData["id"]] = historyAndChartsForRun;
      }
      return historyAndCharts;
    };
    var queriedHistoryAndCharts = result.parsedData;
    chartInfo.value = queriedHistoryAndCharts as Map<String, dynamic>;
  }

  loadRunsAndProjects() async {
    final QueryOptions options = QueryOptions(
      document: gql(r'''
       query {
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
                  displayName
                  sweepName
                  
                  createdAt
                  state
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
    selectedProject.value=projectId;
  }

  void hostChange (String host){
    if(authObject.value==null) {
      authObject.value=AuthObject(host, "", false);
    }
    authObject.value=AuthObject(host,
        authObject.value!.apiKey, false);
  }
  void apiKeyChange (String apiKey){
    if(authObject.value==null) {
      authObject.value=AuthObject("", apiKey, false);
    }
    authObject.value=AuthObject(authObject.value!.host,
        apiKey, false);
  }

  void logout() async {
    prefs.remove("authObject");
    authObject.value= null;
    userProfile.value=null;
    projects.value=[];
    await Get.offAndToNamed("/login");


  }



}

// ALWAYS remember to pass the `Type` you used to register your controller!
