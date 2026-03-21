# AuraLink App
Cliente Flutter para el control remoto total de tu PC.

## Funcionalidades
- **Dashboard en Tiempo Real**: Monitorización de CPU, RAM, Batería y Temperatura.
- **Control de Periféricos**: Sliders interactivos para volumen y brillo.
- **Smart Wake-on-LAN**: Envío de ráfagas de Magic Packets a broadcast universal y subred local.
- **Gestión de Arranque**: 
  - Toque normal: Reiniciar y cambiar de OS.
  - Toque prolongado: Establecer próximo OS sin reiniciar (ideal para el próximo encendido).
- **Interfaz Terminal**: Estética hacker/retro optimizada para modo oscuro.

## Configuración Inicial
1. Al abrir la app, ve a **ENV_CONFIG**.
2. Introduce la IP de tu PC, el puerto (def: 8443) y la MAC de tu tarjeta de red.
3. Asegúrate de que el móvil esté en la misma red WiFi que el PC.

## Compilación
Requiere Flutter SDK.
```bash
flutter pub get
flutter build apk --release
```

## Solución de Problemas (WoL)
Si el PC no enciende:
1. Desactiva el "Inicio Rápido" en los ajustes de energía de Windows.
2. Habilita "Wake on Magic Packet" en la BIOS.
3. Verifica que la MAC introducida sea la correcta (ethernet suele ser más fiable).
