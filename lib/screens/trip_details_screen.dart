import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/trip.dart';
import '../models/station_mark.dart';

class TripDetailsScreen extends StatefulWidget {
  final Trip trip;
  final VoidCallback onTripChanged;
  final VoidCallback onDeleteTrip;

  const TripDetailsScreen({
    super.key,
    required this.trip,
    required this.onTripChanged,
    required this.onDeleteTrip,
  });

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  Timer? _timer;
  bool _isEditingMode = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !_isEditingMode) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _openMap(double lat, double lng) async {
    final Uri geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri, mode: LaunchMode.externalApplication);
    } else {
      final Uri webUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Переименовать группу'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Удалить группу', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteTrip();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog() {
    final controller = TextEditingController(text: widget.trip.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Переименовать группу'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Новое название'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  widget.trip.title = controller.text.trim();
                });
                widget.onTripChanged();
                Navigator.pop(context);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTrip() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить поездку?'),
        content: Text('Вы уверены, что хотите полностью удалить группу "${widget.trip.title}" со всеми станциями?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              widget.onDeleteTrip();
              widget.onTripChanged();
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- УНИВЕРСАЛЬНЫЙ ДИАЛОГ: СОЗДАНИЕ И РЕДАКТИРОВАНИЕ ---
  void _showStationDialog({StationMark? stationToEdit}) {
    final isEditing = stationToEdit != null;
    
    final nameController = TextEditingController(text: isEditing ? stationToEdit.name : '');
    final durationController = TextEditingController(text: isEditing ? stationToEdit.stopDuration.inMinutes.toString() : '15');
    final latController = TextEditingController(text: isEditing ? stationToEdit.latitude?.toString() ?? '' : '');
    final lngController = TextEditingController(text: isEditing ? stationToEdit.longitude?.toString() ?? '' : '');
    
    DateTime selectedMskDateTime;

    if (isEditing) {
      selectedMskDateTime = stationToEdit.arrivalTimeMsk;
    } else if (widget.trip.stations.isNotEmpty) {
      final sorted = List<StationMark>.from(widget.trip.stations)
        ..sort((a, b) => a.arrivalTimeMsk.compareTo(b.arrivalTimeMsk));
      selectedMskDateTime = sorted.last.departureTimeMsk.add(const Duration(hours: 3));
    } else {
      selectedMskDateTime = DateTime.now(); // По умолчанию текущее время (вводим как МСК)
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEditing ? 'Изменить станцию' : 'Добавить станцию'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Название станции'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: durationController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Время стоянки (в минутах)'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: latController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Широта (Lat)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: lngController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Долгота (Lng)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Прибытие (МСК): ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                      Expanded(
                        child: Text(
                          '${selectedMskDateTime.day.toString().padLeft(2,'0')}.${selectedMskDateTime.month.toString().padLeft(2,'0')} '
                          '${selectedMskDateTime.hour.toString().padLeft(2,'0')}:${selectedMskDateTime.minute.toString().padLeft(2,'0')}',
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_month),
                        onPressed: () async {

                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedMskDateTime,
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now().add(const Duration(days: 30)),
                          );
                          if (date == null) return;
                          if (!context.mounted) return;

                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(selectedMskDateTime),
                            builder: (context, child) => MediaQuery(
                              data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                              child: child!,
                            ),
                          );
                          if (time == null) return;

                          if (!context.mounted) return;

                          setDialogState(() {
                            selectedMskDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.trim().isNotEmpty) {
                    final stopMinutes = int.tryParse(durationController.text) ?? 0;
                    final double? lat = double.tryParse(latController.text.trim().replaceAll(',', '.'));
                    final double? lng = double.tryParse(lngController.text.trim().replaceAll(',', '.'));

                    setState(() {
                      if (isEditing) {
                        // Находим старую и заменяем данные
                        final index = widget.trip.stations.indexWhere((s) => s.id == stationToEdit.id);
                        if (index != -1) {
                          widget.trip.stations[index] = StationMark(
                            id: stationToEdit.id,
                            name: nameController.text.trim(),
                            arrivalTimeMsk: selectedMskDateTime,
                            stopDuration: Duration(minutes: stopMinutes),
                            latitude: lat,
                            longitude: lng,
                          );
                        }
                      } else {
                        // Создаем новую
                        widget.trip.stations.add(
                          StationMark(
                            id: DateTime.now().toString(),
                            name: nameController.text.trim(),
                            arrivalTimeMsk: selectedMskDateTime,
                            stopDuration: Duration(minutes: stopMinutes),
                            latitude: lat,
                            longitude: lng,
                        ));
                      }
                    });
                    widget.onTripChanged();
                    Navigator.pop(context);
                  }
                },
                child: Text(isEditing ? 'Сохранить' : 'Добавить'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Сортируем по МСК времени (что аналогично сортировке по местному)
    final sortedStations = List<StationMark>.from(widget.trip.stations)
      ..sort((a, b) => a.arrivalTimeMsk.compareTo(b.arrivalTimeMsk));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.trip.title),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: _showSettingsMenu),
          IconButton(
            icon: Text(_isEditingMode ? '✅' : '📝', style: const TextStyle(fontSize: 20)),
            onPressed: () => setState(() => _isEditingMode = !_isEditingMode),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: sortedStations.isEmpty
                ? const Center(child: Text('Станций пока нет.\nВключите режим редактирования, чтобы добавить.', textAlign: TextAlign.center))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: sortedStations.length,
                    separatorBuilder: (context, index) => const Divider(height: 24),
                    itemBuilder: (context, index) {
                      final station = sortedStations[index];

                      return InkWell(
                        // Если включен режим редактирования — клик по карточке открывает редактирование
                        onTap: _isEditingMode ? () => _showStationDialog(stationToEdit: station) : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(station.statusEmoji, style: const TextStyle(fontSize: 28)),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      station.name,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: _isEditingMode ? Colors.blue : Colors.black, // Подсветим синим, что кликабельно
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Прибытие: ${_formatDateTime(station.arrivalTimeLocal)}\n'
                                      'Стоянка: ${station.stopDuration.inMinutes} мин.\n'
                                      'Отправление: ${_formatDateTime(station.departureTimeLocal)}',
                                      style: TextStyle(color: Colors.grey[700], fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text('(Время местное)', style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic)),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(color: Colors.blueGrey[50], borderRadius: BorderRadius.circular(6)),
                                      child: Text(
                                        station.getTimeLeftLabel(),
                                        style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.blueGrey),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (station.hasCoordinates && !_isEditingMode)
                                    IconButton(
                                      icon: const Icon(Icons.star, color: Colors.amber),
                                      onPressed: () => _openMap(station.latitude!, station.longitude!),
                                    ),
                                  if (_isEditingMode) ...[
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blueAccent),
                                      onPressed: () => _showStationDialog(stationToEdit: station),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                                      onPressed: () {
                                        setState(() {
                                          widget.trip.stations.removeWhere((s) => s.id == station.id);
                                        });
                                        widget.onTripChanged();
                                      },
                                    ),
                                  ]
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_isEditingMode)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _showStationDialog(),
                  icon: const Icon(Icons.add_location_alt),
                  label: const Text('Добавить станцию / метку', style: TextStyle(fontSize: 16)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day.$month $hour:$minute';
  }
}