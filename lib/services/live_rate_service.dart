import 'dart:async';
import '../models/live_rate.dart';
import 'api_service.dart';

/// Service that fetches live metal/stone rates from Hostinger MySQL API.
class LiveRateService {
  final ApiService _apiService = ApiService();

  Stream<LiveRatesData> getLiveRatesStream() async* {
    while (true) {
      try {
        final setting = await _apiService.getSetting('rates');
        if (setting is Map<String, dynamic>) {
          yield LiveRatesData.fromMap(setting);
        } else {
          yield const LiveRatesData();
        }
      } catch (_) {
        yield const LiveRatesData();
      }
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  Future<void> updateRates(Map<String, dynamic> updates) async {
    final current = await _apiService.getSetting('rates');
    final Map<String, dynamic> merged = current is Map<String, dynamic> ? Map<String, dynamic>.from(current) : {};
    merged.addAll(updates);
    await _apiService.saveSetting('rates', merged);
  }
}
