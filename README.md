📖 Introducción
==========
ChaOS es una herramienta que automatiza la detección y prueba de vulnerabilidades en redes inalámbricas mediante ataques de deautenticación. Utilizando herramientas como MDK4 y Airodump-ng, ChaOS permite verificar si tu red WiFi es vulnerable a este tipo de ataques de forma rápida y sencilla.


⚠️ IMPORTANTE - ADVERTENCIA LEGAL
==========
Esta herramienta está diseñada EXCLUSIVAMENTE para:

✅ Pruebas de seguridad en redes propias

✅ Educación en ciberseguridad en entornos controlados

🚫 El uso no autorizado es ILEGAL y puede acarrear consecuencias penales.


🎯 Características Principales
==========
🔍 Escaneo Avanzado
Detección automática de redes WiFi disponibles

📄 Información detallada de cada AP (BSSID, ESSID, Canal)

⚡ Múltiples Modos de Ataque

🎯 Ataque a AP específico - Selecciona un objetivo concreto

📶 Ataque por canal - Afecta todas las redes en un canal específico

🛠️ Instalación
==========
Sistemas Debian, Ubuntu, linux Mint
``` shell
sudo apt update && sudo apt install mdk4 git wireless-tools iw aircrack-ng
```


📥 Paso 1: Clonar el Repositorio
```shell
git clone https://github.com/Zack-Encode/ChaOS
```

📂 Paso 2: Acceder al Directorio
```shell
cd ChaOS
```

🔒 Paso 3: Otorgar Permisos de Ejecución
```shell
chmod +x ChaOS.sh
```

⚡ Paso 4: Ejecutar la Herramienta
```shell
sudo ./ChaOS.sh
```
