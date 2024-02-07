#include <map>
#include <string>
#include <vector>
#include <cmath>
#include <algorithm>

struct DataPoint {
    std::map<std::string, double> values;
};

void applyLogarithmicScale(std::vector<DataPoint>& data, double base = M_E) {
    for (auto& point : data) {
        for (auto& [key, value] : point.values) {
            if (key == "_step" || key == "_runtime") {
                // Apply your expIt equivalent here
            } else {
                value = log(value + 1) / log(base);
            }
        }
    }
}


std::vector<DataPoint> adaptiveAvgPooling(const std::vector<DataPoint>& data, int numPools) {
    std::vector<DataPoint> result;
    if (data.empty()) return result;

    double maxDomain = data.back().values.at("_step"); // Assuming _step is always present
    double poolSize = maxDomain / numPools;

    for (int i = 0; i < numPools; ++i) {
        double lowerBound = i * poolSize;
        double upperBound = (i + 1) * poolSize;
        std::vector<DataPoint> pool;

        for (const auto& point : data) {
            double domainValue = point.values.at("_step"); // Assuming _step is the domain key
            if (domainValue >= lowerBound && domainValue < upperBound) {
                pool.push_back(point);
            }
        }

        if (!pool.empty()) {
            DataPoint avgPoint;
            avgPoint.values["_step"] = (lowerBound + upperBound) / 2;

            // Compute average for other keys
            // ...

            result.push_back(avgPoint);
        }
    }
    return result;
}


std::vector<DataPoint> scaleDownByDomain(const std::vector<DataPoint>& data) {
    if (data.size() < 1000) return data;
    return adaptiveAvgPooling(data, 1000);
}


std::vector<DataPoint> process_chart_data(const std::vector<DataPoint>& data) {
    auto scaledData = applyLogarithmicScale(data); // Note: This modifies the data in place
    return scaleDownByDomain(scaledData);
}


extern "C" {
    std::vector<DataPoint> process_chart_data(const std::vector<DataPoint>& data);
// Declare other functions if they need to be directly accessed from Dart
}
