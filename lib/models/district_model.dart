import 'team.dart';

class DistrictModel {
  final String id;
  final String name;
  final double redDistance;
  final double blueDistance;
  final String? mvpId;
  final String? drama;

  DistrictModel({
    required this.id,
    required this.name,
    this.redDistance = 0.0,
    this.blueDistance = 0.0,
    this.mvpId,
    this.drama,
  });

  Team? get winner {
    if (redDistance == 0 && blueDistance == 0) return null;
    return redDistance > blueDistance ? Team.red : Team.blue;
  }

  double get totalDistance => redDistance + blueDistance;

  double get redPercentage => totalDistance > 0 ? (redDistance / totalDistance) * 100 : 0;
  double get bluePercentage => totalDistance > 0 ? (blueDistance / totalDistance) * 100 : 0;

  double get marginKm => (redDistance - blueDistance).abs();

  bool get isClose => marginKm < (totalDistance * 0.05); // Within 5%

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'redDistance': redDistance,
    'blueDistance': blueDistance,
    'mvpId': mvpId,
    'drama': drama,
  };

  factory DistrictModel.fromJson(Map<String, dynamic> json) => DistrictModel(
    id: json['id'] as String,
    name: json['name'] as String,
    redDistance: (json['redDistance'] as num?)?.toDouble() ?? 0.0,
    blueDistance: (json['blueDistance'] as num?)?.toDouble() ?? 0.0,
    mvpId: json['mvpId'] as String?,
    drama: json['drama'] as String?,
  );

  DistrictModel copyWith({
    String? name,
    double? redDistance,
    double? blueDistance,
    String? mvpId,
    String? drama,
  }) => DistrictModel(
    id: id,
    name: name ?? this.name,
    redDistance: redDistance ?? this.redDistance,
    blueDistance: blueDistance ?? this.blueDistance,
    mvpId: mvpId ?? this.mvpId,
    drama: drama ?? this.drama,
  );
}
