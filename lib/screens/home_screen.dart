import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip.dart';
import 'trip_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Trip> _trips = [];
  bool _isLoading = true; // Флаг загрузки памяти

  @override
  void initState() {
    super.initState();
    _loadTrips(); // Загружаем данные при старте
  }

  // Загрузка данных из локальной памяти
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
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Сохранение текущего состояния в память
  Future<void> _saveTrips() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(_trips.map((t) => t.toJson()).toList());
    await prefs.setString('saved_trips', encodedData);
  }

  void _showCreateTripDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Создать группу (поездку)'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Название поездки',
            hintText: 'например, Омск - Санкт-Петербург',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _trips.add(Trip(
                    id: DateTime.now().toString(),
                    title: controller.text.trim(),
                    stations: [],
                  ));
                });
                _saveTrips(); // Сохраняем после добавления
                Navigator.pop(context);
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои Поездки'),
        elevation: 2,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator()) // Показываем лоадер, пока читается память
          : _trips.isEmpty
              ? const Center(
                  child: Text(
                    'У вас пока нет запланированных поездок.\nНажмите +, чтобы добавить.',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  itemCount: _trips.length,
                  itemBuilder: (context, index) {
                    final trip = _trips[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: ListTile(
                        title: Text(
                          trip.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('Станций: ${trip.stations.length}'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TripDetailsScreen(
                                trip: trip,
                                onTripChanged: () {
                                  setState(() {});
                                  _saveTrips(); // Сохраняем, если внутри поездки что-то изменилось (добавили/удалили станции)
                                },
                                onDeleteTrip: () {
                                  setState(() {
                                    _trips.removeAt(index);
                                  });
                                  _saveTrips(); // Сохраняем после удаления группы
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateTripDialog,
        tooltip: 'Добавить поездку',
        child: const Icon(Icons.add),
      ),
    );
  }
}