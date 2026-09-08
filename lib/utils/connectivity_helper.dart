import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityHelper {
  static Future<bool> isOnline() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final bool linkActive = connectivityResult.any((r) => r != ConnectivityResult.none);
      if (!linkActive) return false;

      if (kIsWeb) {
        return true;
      }

      // Check real internet packet flow via socket connection to a public DNS IP (bypasses DNS resolver timeout lag)
      try {
        final socket = await Socket.connect('8.8.8.8', 53, timeout: const Duration(milliseconds: 1200));
        await socket.close();
        return true;
      } catch (_) {
        try {
          final socket = await Socket.connect('1.1.1.1', 53, timeout: const Duration(milliseconds: 1200));
          await socket.close();
          return true;
        } catch (_) {
          return false;
        }
      }
    } catch (_) {
      // If plugin is not implemented/registered, default to true for native Firestore sync
      return true;
    }
  }
}
