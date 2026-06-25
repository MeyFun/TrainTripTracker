import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Импортируем для фиксации ориентации
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/main_navigation_screen.dart';
import 'helpers/map_cache_helper.dart';

void main() async {
  // Гарантируем инициализацию связок Flutter перед настройкой системных параметров
  WidgetsFlutterBinding.ensureInitialized();

  await MapCacheHelper.init();
  
  // Разрешаем только портретную (вертикальную) ориентацию
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(const TrainTrackerApp());
  });
} 

class TrainTrackerApp extends StatelessWidget {
  const TrainTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Train Station Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        scaffoldBackgroundColor: Colors.white,
      ),
      // --- НАСТРОЙКА ЛОКАЛИЗАЦИИ ---
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ru', 'RU'), // Системный русский язык
      ],
      locale: const Locale('ru', 'RU'), // Принудительно устанавливаем русский интерфейс
      // -----------------------------
      home: const MainNavigationScreen(),
    );
  }
}