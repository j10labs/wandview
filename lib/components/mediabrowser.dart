import 'dart:async';

import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' as material;
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:get/get.dart';
import 'package:get/get_rx/src/rx_workers/utils/debouncer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:wandview/utils/utilities.dart';

import '../utils/controllers.dart';


class MediaBrowserComponent extends StatefulWidget {
  final int maxHistoryLength;
  final String xAxis;

  final dynamic spec;
  final RxList<Map<String, dynamic>> historyWatchable;
  final Function onPressed;
  final Function lastValuesReport;
  final bool isBordered;
  final bool showLastValues;
  final String runName;
  final String visibilityKey;
  final String mediasPath;
  final dynamic run;

  MediaBrowserComponent(
      {super.key,
        this.maxHistoryLength = 600,
        this.isBordered = false,
        this.run,
        required  this.visibilityKey,
        this.showLastValues = false,
        required this.mediasPath,
        required this.xAxis,
        required this.spec,
        required this.runName,
        required this.historyWatchable,
        required this.onPressed,
        required this.lastValuesReport});

  @override
  _MediaBrowserState createState() => _MediaBrowserState();
}

class _MediaBrowserState extends State<MediaBrowserComponent>
    with AutomaticKeepAliveClientMixin {
  late StreamSubscription historyWatchableStream;
  var history = List<Map<String, dynamic>>.empty(growable: true);
  var appController = Get.find<AppController>();
  var disposed = false;
//  String directDownloadUrl = "";
  final audioPlayer=  AudioPlayer();
  var slicedHistory = List<dynamic>.empty(growable: true);
  var isLoaded = true;
  var carouselController = CarouselController();
  var paused = false;
  var mediaSliderIndex = 0.0;
  double? get lastSeenDomain {
    var appSessionId = prefs.getString("appSession")!;
    var runName = widget.runName;
    var lt= prefs.getDouble("$appSessionId:$runName:lastSeenStep");
    return lt;
  }



  late SharedPreferences prefs;

  void loadUp(List<Map<String, dynamic>> _history, {setToState = true}) {

    // Slice the history to only include the last maxHistoryLength entries
    //check if widget is mounted  and not locked
    if (!this.mounted || disposed) {
      return;
    }
    if(widget.spec["config"]["mediaKeys"].length < 1){
      return;
    }
    if (_history.length < 1) {
      return;
    }
    // if (_history.lastOrNull != null &&  widget.spec["config"]["mediaKeys"].length > 0) {
    //   var mediaKey = widget.spec["config"]["mediaKeys"].first;
    //   var lastSeenInMedia = _history.last["l__"+mediaKey];
    //   if (lastSeenInMedia != null){
    //     var privatePath = lastSeenInMedia["path"];
    //     appController.fileQuery(runId: widget.run["name"], projectName: widget.run["project"]["name"],
    //       entityName: widget.run["project"]["entityName"],
    //       filenames: [privatePath],).then((value) => {
    //       if(value.length > 0){
    //         setState(() {
    //           print ("setting direct download url to "+value[privatePath]!);
    //           directDownloadUrl = value[privatePath]!;
    //         })
    //       }
    //     });
    //   }
    //
    // }
    var mediaKey = widget.spec["config"]["mediaKeys"].first;
    _history = _history.where((element) => element[mediaKey] != null).toList();

    if (setToState && this.mounted && !paused) {
      setState(() {
        slicedHistory = _history;
        history = _history;
        mediaSliderIndex = (_history.length-1).toDouble();
        if(carouselController.ready){
          try{
            carouselController.animateToPage(_history.length-1);
          }catch(e){
            print("Error can be ignored: "+e.toString());
          }
        }


      });
    } else {
      slicedHistory = _history;
      history = _history;
    }
  }

  @override
  void deactivate() {
    // TODO: implement deactivate
    //  historyWatchableStream.pause();
    super.deactivate();
  }

  @override
  void activate() {
    // historyWatchableStream.resume();
    // TODO: implement activate
    super.activate();
  }

  get isChartValid {

    return widget.spec.containsKey("viewType") &&
        (widget.spec["viewType"] == "Run History Line Plot"
            || widget.spec["viewType"] == "Media Browser"
        ) &&
        (
            (widget.spec["config"]["metrics"] != null)
                || ((widget.spec["config"]["mediaKeys"] != null) && (widget.spec["config"]["mediaKeys"].length > 0))
        );
  }

  @override
  void initState() {
    // TODO: implement initState
    if (isChartValid) {
      SharedPreferences.getInstance().then((_prefs) {
        prefs = _prefs;
        loadUp(widget.historyWatchable.value.toList(), setToState: true);
        historyWatchableStream = widget.historyWatchable.stream.listen((val) {
          if (disposed) {
            return;
          }

          if (this.mounted) {
            loadUp(val, setToState: true);
            // var applied =  applyLogarithmicScale(gaussianSmoothListMap(scaleDownByDomain((val ))));
            // loadUp(applied);
          }

          // try{
          //
          // }catch(e){
          //   throw e;
          // }
        }, onError: (e) {
          throw e;
        });
      });
    }

    super.initState();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    disposed = true;
    audioPlayer.stop();
    // check if historyWatchableStream is initialized
    try{
      if (isChartValid && (historyWatchableStream!=null)) {
        // check if historyWatchableStream is initialized


        historyWatchableStream.cancel();
      }
    } catch(e){
      print(e);
    }


    super.dispose();
  }


  static num? getLastAvailableValue(
      dynamic hist, int currentIndex, String key) {
    if (currentIndex < 0) {
      currentIndex = hist.length - 1;
    }
    for (int i = currentIndex - 1; i >= 0; i--) {
      if (hist[i].containsKey(key)) {
        if (hist[i][key].runtimeType != int &&
            hist[i][key].runtimeType != double &&
            hist[i][key].runtimeType != num) {
        } else {
          return hist[i][key];
        }
      }
    }
    return null;
  }

  var _debouncerTimer = Timer(Duration(milliseconds: 0), () => {});

  Widget renderMediaBrowser(){
    if (history.length == 0) {
      return Container();
    }

    var mediaKey = widget.spec["config"]["mediaKeys"].first;
   // var relevantHistory = history;
    var lastSeenInMedia = history.last[mediaKey];
    // check if lastSeenInMedia is Map<String, ?>
    if (lastSeenInMedia is! Map){
      return Container();
    }
    // if(lastSeenInMedia == null){
    //   for (var i = history.length - 1; i >= 0; i--) {
    //     var hist = history[i];
    //     if (hist[mediaKey] != null) {
    //       lastSeenInMedia = hist[mediaKey];
    //       break;
    //     }
    //   }
    // }
    if(lastSeenInMedia == null){
      return Container();
    }

    // if(lastSeenInMedia["format"]!="png"){
    //   return Container();
    // }

    return  Container(
      // color: Colors.white,
      width: double.infinity,

      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      margin: EdgeInsets.symmetric(vertical: 5, horizontal: 5),
      decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.1))
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(mediaKey, style:TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8))),
      Container(
          alignment: Alignment.center,
          width: double.infinity,
          margin: EdgeInsets.only(top: 10),
          height: lastSeenInMedia["format"]=="png"? 250: 150,
          child: CarouselSlider.builder(
            itemCount: slicedHistory.length,
carouselController: carouselController,
key: ValueKey("carousel"+mediaKey),
            options: CarouselOptions(
              autoPlay: false,
             // aspectRatio: 16/9,
              enlargeCenterPage: true,
              viewportFraction:lastSeenInMedia["format"]=="png"? 0.7 : 0.4,
              padEnds: true,
              enableInfiniteScroll: false,
           //   animateToClosest: true,
              onPageChanged: (index, reason) {
                // debounce this function
                _debouncerTimer.cancel();
                _debouncerTimer = Timer(Duration(milliseconds: 500), () {
                  setState(() {
                    mediaSliderIndex = index.toDouble();
                  });
                });
              },

              //reverse: true,
             pageSnapping: false,
              initialPage: slicedHistory.length-1,

            ),
            itemBuilder: (BuildContext context, int index, int realIndex) {
              // Determine properties based on scroll position

              var hist = slicedHistory[index];
              var lastSeenInMedia = hist[mediaKey];
              if(lastSeenInMedia == null){
                lastSeenInMedia = hist[mediaKey];
              }
              if(lastSeenInMedia == null){
                return Container();
              }

              var domain = hist["_step"] ?? hist["_runtime"];
              return MediaItem(
                audioPlayer: audioPlayer,
                key: ValueKey("mediaItem"+mediaKey+"${domain}"),
                mediaType: lastSeenInMedia["_type"],
                mediaPath: lastSeenInMedia["path"],
                widthHeight: lastSeenInMedia["format"]=="png" ? (lastSeenInMedia["width"], lastSeenInMedia["height"]) : null,
                step: domain,
                getDirectDownloadUrl: (String path) async {
                  var value = await appController.fileQuery(runId: widget.run["name"], projectName: widget.run["project"]["name"],
                    entityName: widget.run["project"]["entityName"],
                    filenames: [path],);
                  return value[path]!;
                },
              );
            },
          )
      ),
          Slider(

            value: mediaSliderIndex,
            onChanged: (val) {
              setState(() {
                mediaSliderIndex = val;
              });
              carouselController.animateToPage((mediaSliderIndex).floor());
            },
            min: 0.0, max: max(0,slicedHistory.length-1).toDouble(),
            label: "Step: ${slicedHistory[mediaSliderIndex.floor()]["_step"]}",
            activeColor: Colors.blueAccent, inactiveColor: Colors.white.withOpacity(0.5),
          )

          // Container(
          //   alignment: Alignment.center,
          //   width: double.infinity,
          //   margin: EdgeInsets.only(top: 10),
          //   height: 350,
          //   child: (directDownloadUrl.isEmpty) ?
          //   Container(
          //     child:CircularProgressIndicator(),
          //     width: 30,
          //     height: 30,
          //   )
          //       : CachedNetworkImage(
          //     fit: BoxFit.cover,
          //     imageUrl: directDownloadUrl,
          //
          //     placeholder: (context, url) => Container(
          //       child:CircularProgressIndicator(),
          //       width: 30,
          //       height: 30,
          //     ),
          //     errorWidget: (context, url, error) => Icon(Icons.error),
          //
          //   ),)
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine the start index for slicing the history data

    // TODO: implement build
    if (isChartValid && isLoaded) {
      if(widget.spec["config"]["mediaKeys"].length == 0 ){
        return Container();
      }


      //print("rendering image, url= "+this.widget.mediasPath+lastSeenInMedia["path"]);
      //print(lastSeenInMedia);

      return VisibilityDetector(key: ValueKey(widget.visibilityKey), onVisibilityChanged: (VisibilityInfo info) {
        if(info.visibleFraction == 0){
          paused = true;
        }else{
          paused = false;
        }
      },
          child:renderMediaBrowser());
    } else {
      return Container();
    }
  }

  @override
  // TODO: implement wantKeepAlive
  bool get wantKeepAlive => !disposed;
}

class MediaItem extends StatefulWidget {
  final String mediaType;
  final String mediaPath;
  final num? step;
  final AudioPlayer audioPlayer;
  final (num, num)? widthHeight;
  final Future<String> Function(String)  getDirectDownloadUrl;

  final appController = Get.find<AppController>();
  MediaItem({super.key, required this.audioPlayer, this.widthHeight, required this.mediaType, required this.mediaPath, required this.getDirectDownloadUrl, required this.step});
  @override
  _MediaItemState createState() => _MediaItemState();
}

class _MediaItemState extends State<MediaItem> with AutomaticKeepAliveClientMixin{
  var directDownloadUrl = "";
  var destroyed = false;

  @override
  void dispose() {
    // TODO: implement dispose
    destroyed = true;
    super.dispose();
  }
  var lastAccessed = DateTime.now();
  @override
  void activate() {
    // TODO: implement activate
    super.activate();
    lastAccessed = DateTime.now();
  }
  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    waitAndGetDirectDownloadUrl().then((value) {
      if(!destroyed){
        if(widget.mediaType == "video-file"){
          setState(() {
            directDownloadUrl = value;
          });
        }else{
          setState(() {
            directDownloadUrl = value;
          });
        }


      }
    }).catchError((error)=>print(error));
  }

   Future<String> waitAndGetDirectDownloadUrl() async {
    try {
      return await widget.getDirectDownloadUrl(widget.mediaPath);
    } catch (e) {
      print(e);
      if(destroyed){
        return "";
      }else{
        await Future.delayed(Duration(seconds: 3));
        return await waitAndGetDirectDownloadUrl();
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    lastAccessed = DateTime.now();
    if(widget.mediaType == "image-file"){
      var aspectRatio = widget.widthHeight!.$1/widget.widthHeight!.$2;

      return Container(
        padding: EdgeInsets.all(5),
        color: Colors.white.withOpacity(0.2),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [

              Text ("Step ${widget.step?.toInt()}", style:TextStyle(fontSize: 8, color: Colors.white.withOpacity(0.8))),
              SizedBox(height: 2),
              Expanded(child: LayoutBuilder(builder: (context, constraints) {
                return Container(

                    width: constraints.maxWidth,
                    height: constraints.maxWidth * aspectRatio,
                    constraints: BoxConstraints(
                      maxHeight: constraints.maxWidth * aspectRatio,
                      // maxWidth: 300,
                    ),
                    // width: 300,
                    // height: 300 * aspectRatio,

                    child: (directDownloadUrl.isEmpty) ?
                    Container(
                      child:CircularProgressIndicator(),

                      alignment: Alignment.center,
                    )
                        :  CachedNetworkImage(
                      fit: BoxFit.contain,
                      imageUrl: directDownloadUrl,
                      width: constraints.maxWidth,
                      height: constraints.maxWidth * aspectRatio,

                      placeholder: (context, url) => Container(
                        child:CircularProgressIndicator(),
                        width: constraints.maxWidth,
                        height: constraints.maxWidth * aspectRatio,
                        alignment: Alignment.center,
                      ),
                      errorWidget: (context, url, error) => Icon(Icons.error),

                    ));
              })),



            ]
        ),
      );
    } else if(widget.mediaType == "audio-file"){
      return Container(
          padding: EdgeInsets.all(5),
          color: Colors.white.withOpacity(0.2),
          child:Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [

            Text ("Step ${widget.step?.toInt()}", style:TextStyle(fontSize: 8, color: Colors.white.withOpacity(0.8))),
            SizedBox(height: 2),
            Expanded(child: LayoutBuilder(builder: (context, constraints) {
              return Container(
                  height:  constraints.maxHeight,
                  width: constraints.maxWidth,
                  // width: 300,
                  // height: 300 * aspectRatio,

                  child: (directDownloadUrl.isEmpty) ?
                  Container(
                    child:CircularProgressIndicator(),
                    width: constraints.maxWidth,
                    height:  constraints.maxHeight,
                    alignment: Alignment.center,
                  )
                      : AudioItem(key:ValueKey(
                      "videoFile"+directDownloadUrl
                  ) ,audioUrl: directDownloadUrl, audioPlayer: widget.audioPlayer)

              );
            }))
            ,



          ]
      ));
    }
    return Container(
      child: Text("Unsupported media type", style:TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)))
    );

  }

  @override
  // TODO: implement wantKeepAlive
  bool get wantKeepAlive {
    // if it was created less than 2 minutes ago, keep it alive
    return DateTime.now().difference(lastAccessed).inSeconds < 30;
  }
}


class AudioItem extends StatefulWidget {
  final String audioUrl;

  final AudioPlayer audioPlayer;


  AudioItem({super.key, required this.audioUrl, required this.audioPlayer});

  @override
  _AudioItemState createState() => _AudioItemState();
}

class _AudioItemState extends State<AudioItem> with AutomaticKeepAliveClientMixin {
  var isPlaying = false;
  StreamSubscription? playerStateStreamSubscription = null;
  StreamSubscription? eventStreamSubscription = null;
  Duration? duration;
  Duration? position;
  @override
  initState() {
    super.initState();
    // if audioPlayer is playing, and the audioUrl is the same as the one in the widget, set isPlaying to true
    var playerState = widget.audioPlayer.state;
    var url = widget.audioUrl;
    var playerUrl = (widget.audioPlayer.source as UrlSource?)?.url;
    if(playerUrl != null && (playerState == PlayerState.playing && url == playerUrl)){
      setState(() {
        isPlaying = true;
      });
    }
    playerStateStreamSubscription = widget.audioPlayer.onPlayerStateChanged.listen((playerState) {
      var _playerUrl = (widget.audioPlayer.source as UrlSource?)?.url;
      if(_playerUrl == widget.audioUrl ){
        if(playerState == PlayerState.playing){
          setState(() {
            isPlaying = true;
          });
        }else{
          setState(() {
            isPlaying = false;
          });
        }
      }else{
        if(isPlaying){
          setState(() {
            isPlaying = false;
          });
        }
      }
    });
    eventStreamSubscription = widget.audioPlayer.eventStream.listen((event) {
      var playerUrl = (widget.audioPlayer.source as UrlSource?)?.url;
      if(playerUrl == widget.audioUrl){
        if(duration != null && position != null){
          setState(() {
            duration = event.duration;
            position = event.position;
          });
        }

      }
    });
  }
  togglePlay() async {
    var state = await widget.audioPlayer.state;

    if (state == PlayerState.stopped || state == PlayerState.completed || !isPlaying){
      await widget.audioPlayer.stop();

      await widget.audioPlayer.play(UrlSource(widget.audioUrl));
     // setState(() {
     //   isPlaying = true;
     // });

    }else{
      if(state == PlayerState.playing) {
        await widget.audioPlayer.pause();
        // setState(() {
        //   isPlaying = false;
        // });
      } else {

        widget.audioPlayer.resume();
       // setState(() {
       //   isPlaying = true;
       // });
      }
    }

  }
  @override

  dispose() {
    if(playerStateStreamSubscription != null){
      playerStateStreamSubscription!.cancel();
    }
    if(eventStreamSubscription != null){
      eventStreamSubscription!.cancel();
    }
    widget.audioPlayer.pause();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
              iconSize: 70,
              icon: Icon(isPlaying ? Icons.pause: Icons.play_arrow), onPressed: (){
           togglePlay();
          })
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

}
