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

# OTel Collector
ufw allow 30809/tcp comment 'OTel Collector OTLP gRPC'
ufw allow 31947/tcp comment 'OTel Collector OTLP HTTP'

# Jaeger
ufw allow 30686/tcp comment 'Jaeger UI'

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
echo "Ejemplos:"
echo "   Grafana:   http://<node-ip>:30300"
echo "   MinIO:     http://<node-ip>:30901"
echo "   OTel HTTP: http://<node-ip>:31947"
echo "   OTel gRPC: <node-ip>:30809"
echo "   Jaeger:    http://<node-ip>:30686"
echo "   Headlamp:  http://<node-ip>:30850"
