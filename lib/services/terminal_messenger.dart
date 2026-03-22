import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class TerminalMessenger {
  static void show(BuildContext context, String? message, {bool isError = false, bool isSuccess = false}) {
    final String displayMessage = (message == null || message.isEmpty) ? 'UNKNOWN_STATUS' : message;
    
    Color accentColor = AppColors.keyword; // Magenta por defecto (System)
    String prefix = '[ SYSTEM ]';
    
    if (isError) {
      accentColor = Colors.redAccent;
      prefix = '[  ERROR ]';
    } else if (isSuccess) {
      accentColor = Colors.greenAccent;
      prefix = '[ SUCCESS ]';
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E), // Fondo oscuro sólido
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 1),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              Text(
                prefix,
                style: TextStyle(
                  color: accentColor,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  displayMessage.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Un cuadro de aviso integrado en la UI (no flotante)
  static Widget inlineBanner(String label, String sublabel, {bool isError = false}) {
    final Color color = isError ? Colors.redAccent : Colors.orangeAccent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline : Icons.warning_amber_rounded, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'monospace')),
                Text(sublabel, style: const TextStyle(color: Colors.white60, fontSize: 10, fontFamily: 'monospace')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
