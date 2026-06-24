import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'map_trips_list_screen.dart'; // Экран выбора группы для карты

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // Список экранов для переключения
  final List<Widget> _screens = [
    const HomeScreen(),
    const MapTripsListScreen(), // Экран, где выбираем поездку для просмотра на карте
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.train),
            label: 'Мои поездки',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Карта',
          ),
        ],
      ),
    );
  }
}