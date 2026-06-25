import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';

class MapCacheHelper {
  static CacheOptions? _cacheOptions;

  static CacheOptions get cacheOptions {
    if (_cacheOptions == null) {
      throw Exception("MapCacheHelper не был инициализирован.");
    }
    return _cacheOptions!;
  }

  static Future<void> init() async {
    if (_cacheOptions != null) return;

    // Оставляем только базовые, железно существующие параметры во всех версиях 4.x
    _cacheOptions = CacheOptions(
      store: MemCacheStore(), 
      policy: CachePolicy.refreshForceCache, // Форсирует чтение из кэша, если сеть лежит
      maxStale: const Duration(days: 7),
      priority: CachePriority.high,
    );
  }
}