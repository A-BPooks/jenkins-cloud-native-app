#!/bin/bash
set -e
ENVIRONMENT=${1:-dev}
APP_NAME="jenkins-cloud-native-app"

echo "📊 Iniciando monitoreo de ${APP_NAME} en ${ENVIRONMENT}"

# Función para verificar métricas
check_metric() {
    local metric_name=$1
    local threshold=$2
    local query=$3
    
    echo "Verificando ${metric_name}..."
    local value=$(curl -s -G ${PROMETHEUS_URL}/api/v1/query \
        --data-urlencode "query=${query}" | jq -r '.data.result[0].value[1]')
    
    if (( $(echo "$value > $threshold" | bc -l) )); then
        echo "⚠️ ALERTA: ${metric_name} = ${value} (umbral: ${threshold})"
        return 1
    else
        echo "✅ ${metric_name} = ${value}"
        return 0
    fi
}

# Verificar métricas críticas
check_metric "CPU Usage" 80 "avg(rate(container_cpu_usage_seconds_total[5m])) * 100"
check_metric "Memory Usage" 85 "avg(container_memory_usage_bytes / container_spec_memory_limit_bytes) * 100"
check_metric "Error Rate" 5 "sum(rate(app_http_requests_total{status_code=~'5..'}[5m])) / sum(rate(app_http_requests_total[5m])) * 100"
check_metric "Response Time" 500 "avg(rate(app_response_time_seconds_sum[5m]))"

# Verificar health de servicios
echo "🔍 Verificando health de servicios..."
for service in user-service product-service api-gateway; do
    response=$(curl -s -o /dev/null -w "%{http_code}" http://${service}.${ENVIRONMENT}.svc.cluster.local:8080/health)
    if [ "$response" != "200" ]; then
        echo "❌ ${service} no está healthy (HTTP ${response})"
        exit 1
    fi
    echo "✅ ${service} está healthy"
done

echo "📈 Generando informe..."
kubectl top nodes
kubectl top pods -n ${ENVIRONMENT}
echo "✅ Monitoreo completado"