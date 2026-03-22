import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';

class WolService {
  static const _storage = FlutterSecureStorage();

  static Future<void> saveMacAddress(String mac) async {
    await _storage.write(key: 'pc_mac', value: mac);
  }

  static Future<String?> getSavedMac() async {
    return await _storage.read(key: 'pc_mac');
  }

  static Future<WolResult> sendMagicPacket(String macAddress) async {
    try {
      final mac = _parseMac(macAddress);
      if (mac == null) {
        return const WolResult(success: false, message: 'ERR: invalid_mac');
      }
      final packet = Uint8List(102);
      for (int i = 0; i < 6; i++) {
        packet[i] = 0xFF;
      }
      for (int i = 1; i <= 16; i++) {
        for (int j = 0; j < 6; j++) {
          packet[i * 6 + j] = mac[j];
        }
      }

      // Enviar a traves de multiples puertos y direcciones de broadcast comunes
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      
      final broadcastAddresses = [
        InternetAddress('255.255.255.255'),
      ];

      // Intentar deducir el broadcast de la subred a partir de la IP guardada
      final serverIp = ApiService.instance.ip;
      if (serverIp != null && serverIp.contains('.')) {
        final parts = serverIp.split('.');
        if (parts.length == 4) {
          broadcastAddresses.add(InternetAddress('${parts[0]}.${parts[1]}.${parts[2]}.255'));
        }
      }

      for (var address in broadcastAddresses) {
        for (int i = 0; i < 3; i++) { // Repetir 3 veces para mayor seguridad
          socket.send(packet, address, 9); // Puerto WOL estandar
          socket.send(packet, address, 7); // Puerto WOL alternativo
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
      
      socket.close();
      return const WolResult(success: true, message: 'SUCCESS: magic_packet_sent');
    } catch (e) {
      return WolResult(success: false, message: 'ERR: $e');
    }
  }

  static List<int>? _parseMac(String mac) {
    final cleaned = mac.replaceAll(RegExp(r'[:\-]'), '');
    if (cleaned.length != 12) return null;
    try {
      return [
        for (int i = 0; i < 12; i += 2)
          int.parse(cleaned.substring(i, i + 2), radix: 16)
      ];
    } catch (_) {
      return null;
    }
  }
}

class WolResult {
  final bool success;
  final String message;
  const WolResult({required this.success, required this.message});
}
