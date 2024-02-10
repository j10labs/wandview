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


num deExpIt(num y, {double alpha = 0.001}) {
  //reversing exp(α⋅log(x))
  return exp(log(y)/4);
}

num expIt(num x, {double alpha = 0.001}) {
  // Apply exponential growth with controlled scaling
  // absolute
  var y=  exp(4*log(x));
  return y;
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
  double maxDomain = deExpIt(linearValues.last[domainKey] ?? 0.0).toDouble();
  double minDomain = deExpIt(linearValues.first[domainKey] ?? 0.0).toDouble();
  //  interpolate from minDomain to maxDomain to 0 to numPools-1, logaritmically, meaning that the first pool will have a larger range than the last pool
  double logFactor = 1.0;
  var poolRanges = List.generate(numPools + 1, (i) {
    var linearFraction = i / numPools;
    var maxLog = log(numPools + 1); // Adjusted to avoid log(0)
    var iLog = log(i + 1);
    var logFraction = iLog / maxLog;

    // Blend linear and logarithmic fractions using logFactor
    var fraction = (1 - logFactor) * linearFraction + logFactor * logFraction;
    var domainValueInterpolation = minDomain + (fraction * (maxDomain - minDomain));
    return expIt(domainValueInterpolation).toDouble();
  });

  print("poolRanges.first= ${poolRanges.first}");
  print("poolRanges.last= ${poolRanges.last}");

  // Initialize lists for each pool
  List<List<Map<String, dynamic>>> pools = List.generate(numPools, (_) => []);


  // Distribute entries into the correct pools
  for (var entry in linearValues) {
    var domainValue = entry[domainKey];
    int poolIndex = 0;
    for (int i = 0; i < poolRanges.length - 1; i++) {
      if (domainValue >= poolRanges[i] && domainValue < poolRanges[i + 1]) {
        poolIndex = i;
        break;
      }
    }
    //
    pools[poolIndex].add(entry);
  }

  // if length of items in last value is more than 1, then create subsequent items in list to add them
  var lastPool = pools.lastOrNull;

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
      double lowerBound = poolRanges[i];
      double upperBound = poolRanges[i + 1];
      var sumMap = <String, double>{};
      var countMap = <String, int>{};

      for (var entry in pools[i]) {
        entry.forEach((key, value) {
          if(value is num){
            if ( key != "_step" && key != "_runtime" && key != "_timestamp") {
              // Apply logaritmic scale to the value
              var vdm = exp(value) - 1;
              if(vdm.isNaN || vdm.isInfinite){
                throw Exception("NaN or infinite value found in adaptiveAvgPooling");
              }
              sumMap[key] = (sumMap[key] ?? 0) + vdm;
              countMap[key] = (countMap[key] ?? 0) + 1;
            }else{
              sumMap[key] = max(sumMap[key] ?? value.toDouble() , value.toDouble());
              countMap[key] = (countMap[key] ?? 0) + 1;
            }
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
          var v = log((sumMap[k]! / countMap[k]!)+1);
          // crash if v is NaN or infinite
          if(v.isNaN || v.isInfinite){
           throw Exception("NaN or infinite value found in adaptiveAvgPooling");
          }
          return v;
        },
      );
      var dExpLowerBound = deExpIt(lowerBound).toDouble();
      var dExpUpperBound = deExpIt(upperBound).toDouble();
      avgMap[domainKey] = upperBound;


      pooledData.add(avgMap);
    }
  }

  return pooledData;
}

List<Map<String, dynamic>> scaleDownByDomain(List<Map<String, dynamic>> originalList) {
  var totalPoints = originalList.length;
  if (totalPoints < 1000) {
    return originalList;
  }
  var adaptivePooled = adaptiveAvgPooling(originalList, 100);
  return adaptivePooled;
}

List<Map<String,dynamic>> isolatedRun(List<dynamic> vl) {

  if(vl.isEmpty){
    return [];
  }
  print("Processing: ${vl.length} points");
  print(vl.lastOrNull);
  var timeNow = DateTime.now();
  var logarithmicApplication = applyLogarithmicScale(((
      vl.map<Map<String, dynamic>>((v) => (v as Map<String, dynamic>))
      .toList()
      )));
  var applied = scaleDownByDomain(logarithmicApplication);


  var vlLast = vl.last;
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
