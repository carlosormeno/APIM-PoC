#!/bin/bash
# Script para abrir puertos NodePort en UFW para acceso desde Windows
# Ejecutar con: sudo bash fix-firewall-nodeport.sh

echo "🔥 Configurando UFW para permitir acceso a servicios NodePort de Kubernetes..."

# Verificar estado actual
echo "📊 Estado actual de UFW:"
ufw status verbose

# Abrir puertos NodePort específicos
echo ""
echo "🔓 Abriendo puertos NodePort..."

# MinIO
ufw allow 30900/tcp comment 'MinIO API'
ufw allow 30901/tcp comment 'MinIO Console'

# Mage AI
ufw allow 30788/tcp comment 'Mage Bronze'
ufw allow 30789/tcp comment 'Mage Silver'
ufw allow 30790/tcp comment 'Mage Gold'

# Airflow
ufw allow 30809/tcp comment 'Airflow Webserver'

# Spark
ufw allow 30808/tcp comment 'Spark Master UI'
ufw allow 32464/tcp comment 'Spark Master'

# Trino
ufw allow 30810/tcp comment 'Trino Coordinator'
ufw allow 32331/tcp comment 'Trino Metrics'

# Headlamp
ufw allow 30850/tcp comment 'Headlamp K8s UI'

# Monitoring
ufw allow 30300/tcp comment 'Grafana'
ufw allow 30090/tcp comment 'Prometheus'
ufw allow 30100/tcp comment 'Loki'
ufw allow 30093/tcp comment 'Alertmanager'

# Alternativa: Abrir rango completo de NodePort (30000-32767)
# Descomenta la siguiente línea si prefieres abrir todo el rango
# ufw allow 30000:32767/tcp comment 'Kubernetes NodePort range'

echo ""
echo "✅ Reglas agregadas. Recargando UFW..."
ufw reload

echo ""
echo "📊 Estado final de UFW:"
ufw status verbose

echo ""
echo "✨ Configuración completada!"
echo ""
echo "📝 Puedes acceder a los servicios desde Windows usando:"
echo "   - IP Ethernet: 172.16.14.40"
echo "   - IP WiFi: 10.50.129.187"
echo ""
echo "Ejemplos:"
echo "   Grafana:  http://172.16.14.40:30300"
echo "   MinIO:    http://172.16.14.40:30901"
echo "   Airflow:  http://172.16.14.40:30809"
echo "   Headlamp: http://172.16.14.40:30850"
