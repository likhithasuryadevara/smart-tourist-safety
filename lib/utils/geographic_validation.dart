bool isValidCoordinate(double? latitude, double? longitude) =>
    latitude != null &&
    longitude != null &&
    latitude.isFinite &&
    longitude.isFinite &&
    latitude >= -90 &&
    latitude <= 90 &&
    longitude >= -180 &&
    longitude <= 180;

double? finiteNumber(Object? value) {
  if (value is! num) return null;
  final number = value.toDouble();
  return number.isFinite ? number : null;
}

bool isValidRadius(double? radius) =>
    radius != null && radius.isFinite && radius >= 0;
