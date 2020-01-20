#!/bin/bash

PLUGIN_SCRIPT=check_prometheus_metric.sh
NETWORK_NAME=nagios_plugins_testnetwork
PROMETHEUS_NAME=nagios_plugins_prometheus
PROMETHEUS_PORT=8090
PUSHGATEWAY_NAME=nagios_plugins_pushgateway
PUSHGATEWAY_PORT=8091

source tests/utils.sh

echo ""
echo "Creating configuration file"
CONFIG_FILE=$(mktemp --suffix=.yml)
chmod 666 ${CONFIG_FILE}
echo "${CONFIG_FILE}"

echo ""
echo "Templating configuration file"
sed -e "s/\${PUSHGATEWAY_NAME}/${PUSHGATEWAY_NAME}/" tests/prometheus.yml > ${CONFIG_FILE}

echo ""
echo "Creating docker network"
docker network rm ${NETWORK_NAME}
docker network create ${NETWORK_NAME}

echo ""
echo "Starting prometheus container"
docker rm -f ${PROMETHEUS_NAME}
docker run --name ${PROMETHEUS_NAME} --net=${NETWORK_NAME} -d -p ${PROMETHEUS_PORT}:9090 -v ${CONFIG_FILE}:/etc/prometheus/prometheus.yml prom/prometheus

echo ""
echo "Starting pushgateway container"
docker rm -f ${PUSHGATEWAY_NAME}
docker run --name ${PUSHGATEWAY_NAME} --net=${NETWORK_NAME} -d -p ${PUSHGATEWAY_PORT}:9091 prom/pushgateway

echo ""
echo "Waiting until prometheus is up"
until $(curl --output /dev/null --silent --fail http://localhost:${PROMETHEUS_PORT}); do
    printf '.'
    sleep 1
done

echo ""
echo "Waiting until pushgateway is up"
until $(curl --output /dev/null --silent --fail http://localhost:${PUSHGATEWAY_PORT}); do
    printf '.'
    sleep 1
done

echo ""
echo "Pushing pi to pushgateway"
echo "pi 3.14" | curl --data-binary @- http://localhost:${PUSHGATEWAY_PORT}/metrics/job/constants

echo ""
echo "Waiting until prometheus sees itself"
QUERY_SCALAR_UP="scalar(up{instance=\"localhost:9090\"})"
wait_for_metric "${QUERY_SCALAR_UP}" ${PROMETHEUS_PORT}
echo ""

echo ""
echo "Waiting until prometheus sees pushed metric"
wait_for_metric "scalar(pi)" ${PROMETHEUS_PORT}
echo ""

echo "
PLUGIN_SCRIPT=${PLUGIN_SCRIPT}
PROMETHEUS_PORT=${PROMETHEUS_PORT}
PUSHGATEWAY_PORT=${PUSHGATEWAY_PORT}
" > tests/test_config.bash

bats tests/*.bats
