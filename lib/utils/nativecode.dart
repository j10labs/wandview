import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';

base class SimpleDataPoint extends ffi.Struct {
  external ffi.Pointer<ffi.Pointer<ffi.Char>> keys;
  external ffi.Pointer<ffi.Double> values;
  @ffi.Int32()
  external int count;
}

typedef process_chart_data_c_func = ffi.Pointer<SimpleDataPoint> Function(
    ffi.Pointer<SimpleDataPoint> data,
    ffi.Int32 numItems,
    ffi.Int32 numPools,
    ffi.Double expAlpha,
    );

typedef ProcessChartDataC = ffi.Pointer<SimpleDataPoint> Function(
    ffi.Pointer<SimpleDataPoint> data,
    int numItems,
    int numPools,
    double expAlpha,
    );

class WandViewLibrary {
  late ffi.DynamicLibrary _lib;
  late final ProcessChartDataC processChartDataC;

  WandViewLibrary(String pathToLibrary) {
    _lib = ffi.DynamicLibrary.open(pathToLibrary);
    processChartDataC = _lib
        .lookupFunction<process_chart_data_c_func, ProcessChartDataC>('process_chart_data_c');
  }
}

List<Map<String, dynamic>> convertResult(ffi.Pointer<SimpleDataPoint> points, int length) {
  final List<Map<String, dynamic>> dartList = [];

  for (int i = 0; i < length; i++) {
    final simplePoint = points.elementAt(i).ref;
    final Map<String, dynamic> dartMap = {};

    for (int j = 0; j < simplePoint.count; j++) {
      final keyPointer = simplePoint.keys.elementAt(j).value;
      final key = keyPointer.cast<Utf8>().toDartString();
      final value = simplePoint.values.elementAt(j).value;
      dartMap[key] = value;
    }

    dartList.add(dartMap);
  }

  return dartList;
}

ffi.Pointer<Utf8> toNativeString(String str) {
  return str.toNativeUtf8();
}

ffi.Pointer<SimpleDataPoint> convertListToSimpleDataPoints(List<Map<String, dynamic>> dartList) {
  // Allocate memory for the array of SimpleDataPoint structs
  final pointerToArray = calloc<SimpleDataPoint>(dartList.length);

  for (int i = 0; i < dartList.length; i++) {
    final map = dartList[i];
    map.removeWhere((key, value) => value is! num);

    // Allocate memory for keys and values arrays within each SimpleDataPoint struct
    final keysPointer = calloc<ffi.Pointer<ffi.Char>>(map.length);
    final valuesPointer = calloc<ffi.Double>(map.length);

    int j = 0;
    map.forEach((key, value) {
      // Convert string key to native string and store in keys array
      keysPointer[j] = ffi.Pointer<ffi.Char>.fromAddress(toNativeString(key).address);

      // Store double value in values array
      valuesPointer[j] = (value as num).toDouble();
      j++;
    });

    // Populate the SimpleDataPoint struct
    pointerToArray[i].keys = keysPointer;
    pointerToArray[i].values = valuesPointer;
    pointerToArray[i].count = map.length;
  }

  return pointerToArray;
}

