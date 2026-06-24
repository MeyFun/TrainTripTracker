import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip.dart';
import 'map_view_screen.dart';

class MapTripsListScreen extends StatefulWidget {
  const MapTripsListScreen({super.key});

  @override
  State<MapTripsListScreen> createState() => _MapTripsListScreenState();
}

class _MapTripsListScreenState extends State<MapTripsListScreen> {
  List<Trip> _trips = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tripsString = prefs.getString('saved_trips');
    if (tripsString != null) {
      final List<dynamic> decodedList = jsonDecode(tripsString);
      setState(() {
        _trips = decodedList.map((item) => Trip.fromJson(item)).toList();
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Выбор карты маршрута'), elevation: 2),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trips.isEmpty
              ? const Center(child: Text('Сначала создайте поездку во вкладке "Мои поездки"'))
              : ListView.builder(
                  itemCount: _trips.length,
                  itemBuilder: (context, index) {
                    final trip = _trips[index];
                    final validStations = trip.stations.where((s) => s.hasCoordinates).length;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: ListTile(
                        title: Text(trip.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Станций на карте: $validStations из ${trip.stations.length}'),
                        trailing: const Icon(Icons.map_outlined, color: Colors.blue),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MapViewScreen(trip: trip),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}