import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/trip.dart';
import '../models/station_mark.dart';
import 'package:url_launcher/url_launcher.dart';

class MapViewScreen extends StatefulWidget {
  final Trip trip;
  const MapViewScreen({super.key, required this.trip});

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  final MapController _mapController = MapController();
  LatLng? _userLocation; // Локация пользователя
  bool _isLocating = false;

  Future<void> _checkLocation() async {
    if (_userLocation != null) {
      setState(() {
        _userLocation = null;
      });
      return;
    }
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'Геолокация выключена на устройстве.';

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw 'В разрешении отказано.';
      }
      if (permission == LocationPermission.deniedForever) throw 'Разрешения заблокированы.';

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _isLocating = false;
      });

      _mapController.move(_userLocation!, _mapController.camera.zoom);
    } catch (e) {
      setState(() => _isLocating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('GPS: $e')));
      }
    }
  }

  // Вспомогательный метод определения: прошла станция или нет
  bool _isStationPassed(StationMark station, DateTime nowMsk) {
    final departureTime = station.arrivalTimeMsk.add(station.stopDuration);
    return departureTime.isBefore(nowMsk);
  }

  // Динамическое построение цветных отрезков пути
  List<Polyline> _buildColoredPolylines(List<StationMark> validStations) {
    List<Polyline> polylines = [];
    if (validStations.length < 2) return polylines;

    final nowMsk = DateTime.now(); // Текущее время (предполагаем МСК на устройстве или в логике)

    for (int i = 0; i < validStations.length - 1; i++) {
      final s1 = validStations[i];
      final s2 = validStations[i + 1];

      final p1 = LatLng(s1.latitude!, s1.longitude!);
      final p2 = LatLng(s2.latitude!, s2.longitude!);

      final s1Passed = _isStationPassed(s1, nowMsk);
      final s2Passed = _isStationPassed(s2, nowMsk);

      // Если включен режим геолокации И мы находимся на перегоне между Прошедшей и Будущей станцией
      if (_userLocation != null && s1Passed && !s2Passed) {
        // Отрезок 1: От прошедшей станции до человека (Зеленый)
        polylines.add(Polyline(
          points: [p1, _userLocation!],
          color: Colors.green,
          strokeWidth: 4.5,
        ));
        // Отрезок 2: От человека до будущей станции (Синий)
        polylines.add(Polyline(
          points: [_userLocation!, p2],
          color: Colors.blue,
          strokeWidth: 4.5,
        ));
      } else {
        // Стандартная логика времени без GPS или для остальных перегонов
        Color segmentColor;
        if (s1Passed && s2Passed) {
          segmentColor = Colors.green; // Путь от двух прошедших
        } else if (!s1Passed && !s2Passed) {
          segmentColor = Colors.red; // Путь от двух будущих
        } else {
          segmentColor = Colors.blue; // Путь от прошедшей к будущей
        }

        polylines.add(Polyline(
          points: [p1, p2],
          color: segmentColor,
          strokeWidth: 4.5,
        ));
      }
    }
    return polylines;
  }

  @override
  Widget build(BuildContext context) {
    // Отбираем только станции с координатами
    final validStations = widget.trip.stations.where((s) => s.hasCoordinates).toList();
    final nowMsk = DateTime.now();

    // Центрируем карту
    LatLng initialCenter = const LatLng(55.0, 73.0); // Дефолт (Омск)
    if (_userLocation != null) {
      initialCenter = _userLocation!;
    } else if (validStations.isNotEmpty) {
      initialCenter = LatLng(validStations.first.latitude!, validStations.first.longitude!);
    }

    // Сборка маркеров станций
    final markers = validStations.map((station) {
      final passed = _isStationPassed(station, nowMsk);
      return Marker(
        point: LatLng(station.latitude!, station.longitude!),
        width: 120,
        height: 60,
        child: GestureDetector(
          onTap: () => _showStationInfo(context, station),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_on,
                // Прошедшие — зеленые, будущие — красные
                color: passed ? Colors.green : Colors.red,
                size: 34,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: passed ? Colors.green : Colors.red, width: 1),
                ),
                child: Text(
                  station.name,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();

    // Добавляем маркер пользователя, если GPS включен
    if (_userLocation != null) {
      markers.add(
        Marker(
          point: _userLocation!,
          width: 40,
          height: 40,
          child: const Icon(
            Icons.navigation,
            color: Colors.blueAccent,
            size: 32,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Карта: ${widget.trip.title}'),
      ),
      body: validStations.isEmpty && _userLocation == null
          ? const Center(child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text('Нет станций с координатами.\nЗадайте их в режиме редактирования группы.', textAlign: TextAlign.center),
            ))
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: 6.0,
                maxZoom: 18.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.train_project',
                ),
                // Рисуем наши разноцветные перегоны путей
                PolylineLayer(
                  polylines: _buildColoredPolylines(validStations),
                ),
                MarkerLayer(markers: markers),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLocating ? null : _checkLocation,
        backgroundColor: _userLocation != null ? Colors.redAccent : Colors.blue,
        foregroundColor: Colors.white,
        child: _isLocating 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(_userLocation != null ? Icons.gps_off : Icons.gps_fixed),
      ),
    );
  }

  // Метод открытия внешнего приложения карт по координатам
  Future<void> _openExternalMap(double lat, double lng) async {
    final Uri geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть внешние карты')),
        );
      }
    }
  }

  void _showStationInfo(BuildContext context, StationMark station) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                station.name, 
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 8),
              Text(
                'Прибытие (МСК): ${station.arrivalTimeMsk.day.toString().padLeft(2,'0')}.${station.arrivalTimeMsk.month.toString().padLeft(2,'0')} в ${station.arrivalTimeMsk.hour.toString().padLeft(2,'0')}:${station.arrivalTimeMsk.minute.toString().padLeft(2,'0')}'
              ),
              Text('Время стоянки: ${station.stopDuration.inMinutes} мин.'),
              const SizedBox(height: 4),
              if (station.latitude != null && station.longitude != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Координаты: ${station.latitude!.toStringAsFixed(5)}, ${station.longitude!.toStringAsFixed(5)}', 
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Кнопка в виде карты для открытия внешнего приложения
                    IconButton(
                      icon: const Icon(Icons.map, color: Colors.blue),
                      tooltip: 'Открыть в картах телефона',
                      onPressed: () => _openExternalMap(station.latitude!, station.longitude!),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}