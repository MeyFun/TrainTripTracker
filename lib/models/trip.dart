import 'station_mark.dart';

class Trip {
  final String id;
  String title;
  final List<StationMark> stations;

  Trip({
    required this.id,
    required this.title,
    required this.stations,
  });

  // --- КОНВЕРТАЦИЯ ДЛЯ ХРАНЕНИЯ В ПАМЯТИ ---
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'stations': stations.map((s) => s.toJson()).toList(),
      };

  factory Trip.fromJson(Map<String, dynamic> json) {
    var stationsList = json['stations'] as List;
    return Trip(
      id: json['id'],
      title: json['title'],
      stations: stationsList.map((s) => StationMark.fromJson(s)).toList(),
    );
  }
}