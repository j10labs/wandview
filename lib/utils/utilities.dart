import 'dart:convert';
import 'dart:math';
import 'package:color/color.dart' hide Color;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';


String generateRandomString() {
  // Generate a random string of 10 characters
  var random = Random();
  var values = List<int>.generate(20, (i) => random.nextInt(255));
  return base64Url.encode(values);
}
Color generateUniqueLabColor(Random random) {

  // Choose a mid-range lightness for good visibility
  double L = 50.0;

  // Generate a* and b* values within a selected range to avoid extreme saturation
  double a = random.nextDouble() * 200 - 100; // Example range from -100 to 100
  double b = random.nextDouble() * 200 - 100; // Example range from -100 to 100

  // Create a Lab color
  CielabColor labColor = CielabColor(L, a, b);

  // Convert Lab to RGB (using a library or conversion function)
  RgbColor rgbColor = labColor.toRgbColor();

  // Convert to a Flutter color object
  return Color.fromRGBO(rgbColor.r.toInt(), rgbColor.g.toInt(), rgbColor.b.toInt(), 1.0);
}
Color seedToColor(String seed) {
  // Handle special cases
  if (seed == "_step" || seed == "_runtime") {
    return Colors.black;
  }


  // Convert the seed to a byte array
  var bytes = utf8.encode(seed);

  // Hash the byte array using SHA-256
  var hash = sha256.convert(bytes);

  // Use the hash to generate the color components
  var generatedSubNumber = _bytesToInt(hash.bytes.sublist(0, 4));
  var colorRandom = Random(generatedSubNumber);
  //return generateUniqueLabColor(colorRandom);

  // Generate a color in HSV with good contrast against white

  double saturation = 0.6 + colorRandom.nextDouble() * 0.3; // Saturation from 0.6 to 1.0 for intensity
  double value = 0.6 + colorRandom.nextDouble() * 0.2; // Value from 0.2 to 0.5 for lower brightness
  double hue1 = colorRandom.nextDouble() * 360; // Hue from 0 to 360
  double hue2 = colorRandom.nextDouble() * 360; // Hue from 0 to 360
  double hue3 = colorRandom.nextDouble() * 360; // Hue from 0 to 360
  double hue = [hue1, hue2, hue3][colorRandom.nextInt(3)]; // Pick one of the hues
  return HSVColor.fromAHSV(1.0, hue, saturation, value).toColor();
}

int _bytesToInt(List<int> bytes) {
  return bytes.fold(0, (int sum, byte) => sum * 250 + byte);
}


var deExpCache = <double, double>{};
num deExpIt(num y, {double alpha = 1000}) {
  // if (y == 0) {
  //   return 0;
  // }
  var dblY = y.toDouble();//.toString();
  if (deExpCache.containsKey(dblY)) {
    return deExpCache[dblY]!;
  }
  var vx = (pow(y, 1/1.6) - 1).toDouble();
  deExpCache[dblY] = vx;
  return vx;
}
var expCache = <double, double>{};
num expIt(num x, {double alpha = 1000}) {
  // Apply exponential growth with controlled scaling
  // absolute
  var xDbl = x.toDouble();//.toString();
  if (expCache.containsKey(xDbl)) {
    return expCache[xDbl]!;
  }
  var y= pow((x+1), 1.6).toDouble();
  expCache[xDbl] = y;
  return y;
}


num logIt(num x, minimumXValue) {
  if (minimumXValue < 0){
    x += -minimumXValue;
  }
  var y = log(x + 1);

  if (y.isNaN || y.isInfinite){
    throw Exception("NaN - or infinite value found in logIt: ${x}");
  }
  return y;
}

num deLogIt(num y, minimumXValue) {
  var x =  exp(y) - 1;
  if (minimumXValue < 0){
    x += minimumXValue;
  }
  if (x.isNaN || x.isInfinite){
    throw Exception("NaN 0 or infinite value found in deLogIt ${y}");
  }
  return x;
}



List<Map<String, dynamic>> applyLogarithmicScale(
    List<Map<String, dynamic>> originalList,
    {num base = e}) {
  return originalList.map((set) {
    return set.map<String, dynamic>((String key, dynamic value) {
      if(key == "_timestamp"){
        return MapEntry(key, value is num ? ((((value)))) : value);
      }
      if (key == "_step" || key == "_runtime") {
        return MapEntry(key, value is num ? (expIt(((value)))) : value);
      }
      return MapEntry(key, value is num ? log((value) + 1)  : value);
    });
  }).toList();
}

List<Map<String, dynamic>> adaptiveAvgPooling(List<Map<String, dynamic>> linearValues, int numPools) {

  var domainKey = linearValues.first.containsKey("_step") ? "_step" : "_runtime";
  double maxDomain = (linearValues.last[domainKey]??0.0).toDouble();
  double minDomain = (linearValues.first[domainKey]??0.0).toDouble();
  //  interpolate from minDomain to maxDomain to 0 to numPools-1, logaritmically, meaning that the first pool will have a larger range than the last pool
  double logFactor = 0.6;
  var poolRanges = List.generate(numPools + 1, (i) {
    var linearFraction = i / numPools;
    var maxLog = log(numPools + 1); // Adjusted to avoid log(0)
    var iLog = log(i + 1);
    var logFraction = iLog / maxLog;

    // Blend linear and logarithmic fractions using logFactor
    var fraction = (1 - logFactor) * linearFraction + logFactor * logFraction;
    var domainValueInterpolation = minDomain + (fraction * (maxDomain - minDomain));
    return  (domainValueInterpolation).toDouble();
  });

  print("poolRanges.first= ${poolRanges.first}");
  print("poolRanges.last= ${poolRanges.last}");

  // Initialize lists for each pool
  List<List<Map<String, dynamic>>> pools = List.generate(numPools, (_) => []);


  // Distribute entries into the correct pools

  for (var (i,entry) in linearValues.indexed) {
    var domainValue = (entry[domainKey]??0.0).toDouble();
    //var domainValue = entry[domainKey];
    int poolIndex = 0;
    for (int i = 0; i < poolRanges.length - 1; i++) {
      var lowerBound = poolRanges[i];
      var upperBound = poolRanges[i + 1];
      if ((domainValue >= lowerBound) && (
      (upperBound == null) || domainValue <= upperBound
      )) {
        poolIndex = i;
        break;
      }
    }
    //
    pools[poolIndex].add(entry);
  }

  // from the firstPool, cut first 5 items and add them to them as separate pools
  var firstPool = pools.firstOrNull;
  if(firstPool != null && firstPool.length > 10){
    var first10 = firstPool.sublist(0, 5);
    pools.first = pools.first.sublist(5);
    for (var i = 0; i < first10.length; i++) {
     // add them consecutively, starting from the 0..n
      pools.insert(i, [first10[i]]);
  //    poolRanges.insert(i, first10[i][domainKey].toDouble());
    }
    firstPool = pools.firstOrNull;
  }

  // if length of items in last value is more than 1, then create subsequent items in list to add them
  var lastPool = pools.lastOrNull;

  if(lastPool != null && lastPool.length > 10){
    var last10 = lastPool.sublist(lastPool.length - 5);
    pools.last = pools.last.sublist(0, pools.last.length - 5);
    pools.add(last10);
    lastPool = pools.lastOrNull;
    //
  }

  if(lastPool != null && lastPool.length > 1){
    var lastPoolCopy = List.from(lastPool);
    pools.removeLast();
    for (var i = 0; i < lastPoolCopy.length; i++) {

      pools.add([lastPoolCopy[i]]);

    }
    //
  }

  // Calculate averages for each pool
  List<Map<String, dynamic>> pooledData = [];
  for (var i = 0; i < pools.length; i++) {
    if (pools[i].isNotEmpty) {
      if(pools[i].length == 1){
        pooledData.add(pools[i].first);
        continue;
      }
    //  double lowerBound = poolRanges[i];
     // double upperBound = poolRanges[i + 1];
      var sumMap = <String, dynamic>{};
      var countMap = <String, int>{};

      for (var entry in pools[i]) {
        entry.forEach((key, value) {
          if(value is num){
            if ( key != "_step" && key != "_runtime" && key != "_timestamp") {
              // Apply logaritmic scale to the value
              var vdm = value;//exp(value) - 1;
              if(vdm.isNaN || vdm.isInfinite){
                throw Exception("NaN or infinite value found in adaptiveAvgPooling");
              }
              sumMap[key] = (sumMap[key] ?? 0) + vdm;
              countMap[key] = (countMap[key] ?? 0) + 1;
            }else{
              sumMap[key] = max(((sumMap[key] as double?) ?? value.toDouble())  , value.toDouble());
              if (key != "_timestamp"){
                sumMap[key] = (sumMap[key]!).toDouble();
              }
              countMap[key] = (countMap[key] ?? 0) + 1;
            }
          } else if (value != null){
            sumMap[key] = value; // could be string or map or bool
            countMap[key] = (countMap[key] ?? 0) + 1;
          }

        });
      }

      var avgMap = Map<String,dynamic>.fromIterable(
        sumMap.keys,
        key: (k) => k,
        value: (k) {
          if( k == "_step" || k == "_runtime" || k == "_timestamp"){
            return  sumMap[k]!;
          }
          if (sumMap[k] == null || countMap[k] == null){
            return null;
          }
          if (sumMap[k] is! num && sumMap[k] != null){
            return sumMap[k];
          }
          var v = (sumMap[k]! / countMap[k]!);
          // crash if v is NaN or infinite
          if(v.isNaN || v.isInfinite){
           throw Exception("NaN or infinite value found in adaptiveAvgPooling");
          }
          return v;
        },
      );
      // var dExpLowerBound = deExpIt(lowerBound).toDouble();
      // var dExpUpperBound = deExpIt(upperBound).toDouble();
     // avgMap[domainKey] =lowerBound; //dExpUpperBound;


      pooledData.add(avgMap);
    }
  }

  return pooledData;
}

List<Map<String, dynamic>> scaleDownByDomain(List<Map<String, dynamic>> originalList) {
  var totalPoints = originalList.length;
  if (totalPoints < 90) {
    return originalList;
  }
  var adaptivePooled = adaptiveAvgPooling(originalList, 90);
  return adaptivePooled;
}

List<Map<String, dynamic>> fillNullFromPreviousValue(List<Map<String, dynamic>> originalList) {
  var filledList = <String, dynamic>{};
  var totalList = <Map<String, dynamic>>[];
  for (var entry in originalList) {
    var filledEntry = <String, dynamic>{};
    for (var key in entry.keys) {
      if (entry[key] == null) {
        filledEntry[key] = filledList[key];
      } else {
        filledEntry[key] = entry[key];
        filledList[key] = entry[key];
      }
    }
    totalList.add(filledEntry);
  }
  return totalList;
}

List<Map<String,dynamic>> isolatedRun(List<dynamic> vl) {

  if(vl.isEmpty){
    return [];
  }
  print("Processing: ${vl.length} points");
  print(vl.lastOrNull);
  var timeNow = DateTime.now();
  var vx = (
      vl.map<Map<String, dynamic>>((v) => (v as Map<String, dynamic>))
          .toList()
  );
  vx = fillNullFromPreviousValue(vx);
  //var logarithmicApplication = applyLogarithmicScale((vx));
  var applied = scaleDownByDomain(vx);



  for (var tvl in vl){
    for (var entry in tvl.entries){
      if(entry.value != null){
        applied.last["l__${entry.key}"] = entry.value;
      }
    }
  }
  var timeAfter = DateTime.now();
  var calculatedDuration = timeAfter.difference(timeNow);
  print("Time took for computation: ${calculatedDuration.inSeconds}s");

  return applied;

  // var result = wandViewLibrary.processChartDataC(inputDataPointer, numItems, numPools, expAlpha);
  //
  // return applied.map<Map<String,dynamic>>((e) => e).toList();
}
