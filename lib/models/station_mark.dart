enum StationStatus { upcoming, current, passed }

class StationMark {
  final String id;
  final String name;
  final DateTime arrivalTimeMsk;
  final Duration stopDuration;
  final DateTime departureTimeMsk;
  
  final double? latitude;
  final double? longitude;

  StationMark({
    required this.id,
    required this.name,
    required this.arrivalTimeMsk,
    required this.stopDuration,
    this.latitude,
    this.longitude,
  }) : departureTimeMsk = arrivalTimeMsk.add(stopDuration);

  DateTime get arrivalTimeLocal => _mskToLocal(arrivalTimeMsk);
  DateTime get departureTimeLocal => _mskToLocal(departureTimeMsk);

  static DateTime _mskToLocal(DateTime mskDateTime) {
    final now = DateTime.now();
    final localOffset = now.timeZoneOffset;
    const mskOffset = Duration(hours: 3);

    final diff = localOffset - mskOffset;
    return mskDateTime.add(diff);
  }

  bool get hasCoordinates => latitude != null && longitude != null;

  StationStatus get status {
    final now = DateTime.now();
    if (now.isBefore(arrivalTimeLocal)) {
      return StationStatus.upcoming;
    } else if (now.isAfter(arrivalTimeLocal) && now.isBefore(departureTimeLocal)) {
      return StationStatus.current;
    } else {
      return StationStatus.passed;
    }
  }

  String get statusEmoji {
    switch (status) {
      case StationStatus.upcoming: return '❌';
      case StationStatus.current: return '🔶';
      case StationStatus.passed: return '✅';
    }
  }

  String getTimeLeftLabel() {
    final now = DateTime.now();
    switch (status) {
      case StationStatus.upcoming:
        return 'До прибытия: ${_formatDuration(arrivalTimeLocal.difference(now))}';
      case StationStatus.current:
        return 'До отправления: ${_formatDuration(departureTimeLocal.difference(now))}';
      case StationStatus.passed:
        return 'Проехали ${_formatDuration(now.difference(departureTimeLocal))} назад';
    }
  }

  String _formatDuration(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    if (days > 0) return '$days д. $hours ч. $minutes мин.';
    if (hours > 0) return '$hours ч. $minutes мин.';
    return '$minutes мин.';
  }

  // --- КОНВЕРТАЦИЯ ДЛЯ ХРАНЕНИЯ В ПАМЯТИ ---
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'arrivalTime': arrivalTimeMsk.toIso8601String(),
        'stopDuration': stopDuration.inMinutes,
        'latitide': latitude,
        'longitude': longitude,
      };

  factory StationMark.fromJson(Map<String, dynamic> json) => StationMark(
        id: json['id'],
        name: json['name'],
        arrivalTimeMsk: DateTime.parse(json['arrivalTime']),
        stopDuration: Duration(minutes: json['stopDuration']),
        latitude: json['latitide'],
        longitude: json['longitude'],
      );
}