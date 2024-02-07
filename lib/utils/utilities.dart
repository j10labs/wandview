import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';


String generateRandomString() {
  // Generate a random string of 10 characters
  var random = Random();
  var values = List<int>.generate(20, (i) => random.nextInt(255));
  return base64Url.encode(values);
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

  // Generate a color in HSV with good contrast against white
  double hue1 = colorRandom.nextDouble() * 360; // Hue from 0 to 360
  double hue2 = colorRandom.nextDouble() * 360; // Hue from 0 to 360
  double hue3 = colorRandom.nextDouble() * 360; // Hue from 0 to 360
  double hue = [hue1, hue2, hue3][colorRandom.nextInt(3)]; // Pick one of the hues
  double saturation = 0.7 + colorRandom.nextDouble() * 0.3; // Saturation from 0.6 to 1.0 for intensity
  double value = 0.6 + colorRandom.nextDouble() * 0.2; // Value from 0.2 to 0.5 for lower brightness

  return HSVColor.fromAHSV(1.0, hue, saturation, value).toColor();
}

int _bytesToInt(List<int> bytes) {
  return bytes.fold(0, (int sum, byte) => sum * 256 + byte);
}


num deExpIt(num y, {double alpha = 0.00001}) {
  // Inverse of the controlled exponential growth
  var logRes = log(y)/alpha;
  return logRes;//min(logRes, 130000);
}

num expIt(num x, {double alpha = 0.00001}) {
  // Apply exponential growth with controlled scaling
  var exp1s = exp(alpha * x);
  return exp1s;
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
  double maxDomain = linearValues.last[domainKey] ?? 0.0;
  List<double> poolRanges = List.generate(numPools + 1, (i) => i * (maxDomain / numPools));

  // Initialize lists for each pool
  List<List<Map<String, dynamic>>> pools = List.generate(numPools, (_) => []);

  // Distribute entries into the correct pools
  for (var entry in linearValues) {
    var domainValue = entry[domainKey];
    int poolIndex = (domainValue / (maxDomain / numPools)).floor().clamp(0, numPools - 1);
    pools[poolIndex].add(entry);
  }

  // Calculate averages for each pool
  List<Map<String, dynamic>> pooledData = [];
  for (var i = 0; i < numPools; i++) {
    if (pools[i].isNotEmpty) {
      double lowerBound = poolRanges[i];
      double upperBound = poolRanges[i + 1];
      var sumMap = <String, double>{};
      var countMap = <String, int>{};

      for (var entry in pools[i]) {
        entry.forEach((key, value) {
          if (key != '_step' && key != '_runtime' && value is num) {
            sumMap[key] = (sumMap[key] ?? 0) + value;
            countMap[key] = (countMap[key] ?? 0) + 1;
          }
        });
      }

      var avgMap = Map<String,dynamic>.fromIterable(
        sumMap.keys,
        key: (k) => k,
        value: (k) => sumMap[k]! / countMap[k]!,
      );
      avgMap[domainKey] = (lowerBound + upperBound) / 2;
      pooledData.add(avgMap);
    }
  }

  return pooledData;
}

List<Map<String, dynamic>> scaleDownByDomain(List<Map<String, dynamic>> originalList) {
  var totalPoints = originalList.length;
  if (totalPoints < 600) {
    return originalList;
  }
  return adaptiveAvgPooling(originalList, 600);
}

List<Map<String,dynamic>> isolatedRun(List<dynamic> vl) {
  print("Processing: ${vl.length} points");
  if(vl.isEmpty){
    return [];
  }
  var timeNow = DateTime.now();
  var logarithmicApplication = applyLogarithmicScale(((
      vl.map<Map<String, dynamic>>((v) => (v as Map<String, dynamic>))
      .toList()
      )));
  var applied = scaleDownByDomain(logarithmicApplication);


  var vlLast = vl.last as Map<String,dynamic>;
  for (var entry in vlLast.entries){
    applied.last["l__${entry.key}"] = entry.value;
  }
  var timeAfter = DateTime.now();
  var calculatedDuration = timeAfter.difference(timeNow);
  print("Time took for computation: ${calculatedDuration.inSeconds}s");

  return applied;

  // var result = wandViewLibrary.processChartDataC(inputDataPointer, numItems, numPools, expAlpha);
  //
  // return applied.map<Map<String,dynamic>>((e) => e).toList();
}
