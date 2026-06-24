import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/trip.dart';
import '../models/station_mark.dart';

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

  // Метод ручного определения геопозиции
  Future<void> _checkLocation() async {
    if (_userLocation != null){
      setState(() {
        _userLocation = null;
      });
      return;
    }
    setState(() => _isLocating = true);
    try {
      // Проверяем, включена ли геолокация на телефоне
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Геолокация выключена на устройстве. Включите её в настройках.';
      }

      // Проверяем права приложения
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Доступ к геолокации отклонен.';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Доступ к геолокации отклонен навсегда в настройках телефона.';
      }

      // Получаем текущие координаты (таймаут 15 сек, чтобы не зависало в глуши)
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _isLocating = false;
      });

      // Перемещаем камеру карты на пользователя
      _mapController.move(_userLocation!, 9.0);

    } catch (e) {
      setState(() => _isLocating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  // Алгоритм построения линий (Пункт 6 вашего ТЗ)
  List<Polyline> _buildPolylines(List<StationMark> stations) {
    if (stations.length < 2) return [];

    List<LatLng> points = [];
    
    // Если геолокация не определена, просто соединяем все точки по порядку
    if (_userLocation == null) {
      for (var s in stations) {
        points.add(LatLng(s.latitude!, s.longitude!));
      }
      return [
        Polyline(points: points, strokeWidth: 4.0, color: Colors.blue),
      ];
    }

    // Логика внедрения человека МЕЖДУ станциями
    // Ищем, между какими двумя станциями по времени сейчас находится поезд
    int insertIndex = -1;
    final now = DateTime.now();

    for (int i = 0; i < stations.length - 1; i++) {
      final currentStation = stations[i];
      final nextStation = stations[i + 1];

      // Если мы уже уехали со станции А, но еще не доехали до станции Б
      if (now.isAfter(currentStation.departureTimeLocal) && now.isBefore(nextStation.arrivalTimeLocal)) {
        insertIndex = i + 1; // Человек должен быть вставлен ПОСЛЕ текущей станции
        break;
      }
    }

    // Строим итоговый массив точек
    for (int i = 0; i < stations.length; i++) {
      // Если мы дошли до индекса, где между станциями находится человек, сначала добавляем человека
      if (i == insertIndex) {
        points.add(_userLocation!);
      }
      points.add(LatLng(stations[i].latitude!, stations[i].longitude!));
    }

    // Случай, если поезд уже проехал ВСЕ станции, а конечная осталась позади (человек в самом конце)
    if (insertIndex == -1 && now.isAfter(stations.last.departureTimeLocal)) {
      points.add(_userLocation!);
    }
    // Случай, если путешествие еще не началось (человек перед первой станцией)
    if (insertIndex == -1 && now.isBefore(stations.first.arrivalTimeLocal)) {
      points.insert(0, _userLocation!);
    }

    return [
      Polyline(points: points, strokeWidth: 4.0, color: Colors.deepPurple, isDotted: false),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Фильтруем только те станции, у которых заданы координаты
    final validStations = widget.trip.stations.where((s) => s.hasCoordinates).toList()
      ..sort((a, b) => a.arrivalTimeMsk.compareTo(b.arrivalTimeMsk));

    // Вычисляем начальный центр карты (берём первую станцию или дефолт)
    final LatLng initialCenter = validStations.isNotEmpty
        ? LatLng(validStations.first.latitude!, validStations.first.longitude!)
        : const LatLng(54.939620, 73.385945); // Омск по дефолту

    // Собираем маркеры станций
    List<Marker> markers = validStations.map((station) {
      return Marker(
        point: LatLng(station.latitude!, station.longitude!),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${station.name}\n${station.getTimeLeftLabel()}')),
            );
          },
          child: Text(station.statusEmoji, style: const TextStyle(fontSize: 24)),
        ),
      );
    }).toList();

    // Если местоположение пользователя определено, добавляем его синий маркер
    if (_userLocation != null) {
      markers.add(
        Marker(
          point: _userLocation!,
          width: 50,
          height: 50,
          child: const Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.circle, color: Colors.white, size: 22),
              Icon(Icons.my_location, color: Colors.blue, size: 20),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Карта: ${widget.trip.title}')),
      body: validStations.isEmpty
          ? const Center(child: Text('У станций этой поездки нет координат.\nЗадайте их в режиме редактирования групп.', textAlign: TextAlign.center))
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: 6.0,
                maxZoom: 18.0,
              ),
              children: [
                // Слой карты (OpenStreetMap) с автоматическим дисковым кэшированием самого флаттера
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.train_project',
                ),
                // Слой линий пути
                PolylineLayer(
                  polylines: _buildPolylines(validStations),
                ),
                // Слой точек (вокзалы и я)
                MarkerLayer(markers: markers),
              ],
            ),
      // Кнопка ручного обновления геопозиции в углу
      floatingActionButton: FloatingActionButton(
        onPressed: _isLocating ? null : _checkLocation,
        backgroundColor: _userLocation != null ? Colors.redAccent : Colors.blue,
        foregroundColor: Colors.white,
        child: _isLocating 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(_userLocation != null ? Icons.gps_off : Icons.gps_fixed), // Меняем иконку при включенном GPS
      ),
    );
  }
}