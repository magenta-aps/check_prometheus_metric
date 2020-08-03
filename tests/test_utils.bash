function test_parameters_full() {
    local _PARAMETERS
    local _OUTPUT
    _PARAMETERS=$1
    _OUTPUT=$(bash ${PLUGIN_SCRIPT} -H "${PROMETHEUS_SERVER}" ${_PARAMETERS} -n "tc")
    printf '%s' "${_OUTPUT}"
    return 0
}

function test_parameters() {
    local _PARAMETERS
    local _OUTPUT
    _PARAMETERS=$1
    _OUTPUT=$(bash ${PLUGIN_SCRIPT} -H "${PROMETHEUS_SERVER}" ${_PARAMETERS} -n "tc" | tail -1)
    printf '%s' "${_OUTPUT}"
    return 0
}

function wait_for_metric() {
    local _RAW_RESULT
    local _PARSED_RESULT="NaN"
    local _EXPECTED_RESULT="$2"
    # Keep running query until data is found, i.e. non-nan returned
    until [ "${_PARSED_RESULT}" == "${_EXPECTED_RESULT}" ]; do
        printf '.'
        sleep 1
        _RAW_RESULT=$(curl -s --data-urlencode "query=$1" "http://localhost:${PROMETHEUS_PORT}/api/v1/query")
        _PARSED_RESULT=$(echo "${_RAW_RESULT}" | jq -r .data.result[1])
    done
    printf '%s' "${_PARSED_RESULT}"
    return 0
}

function set_metric() {
    echo "$1 $2" | curl -s --data-binary @- http://localhost:${PUSHGATEWAY_PORT}/metrics/job/constrants 1>/dev/null 2>/dev/null
}

function build_script() {
    echo ""
    echo "Compiling script"
    mkdir -p build/
    bash tools/compile.sh > ${PLUGIN_SCRIPT}
    chmod +x ${PLUGIN_SCRIPT}
}

function start_docker_network() {
    echo ""
    echo "Creating docker network"
    docker network rm ${NETWORK_NAME}
    docker network create ${NETWORK_NAME}
}

function start_nginx_basic_auth() {
    echo ""
    echo "Creating configuration file"
    CONFIG_FILE=$(mktemp --suffix=.conf)
    chmod 666 ${CONFIG_FILE}
    echo "${CONFIG_FILE}"

    echo ""
    echo "Templating configuration file"
    cp tests/configuration/nginx.conf ${CONFIG_FILE}
    sed -e "s/\${PROMETHEUS_NAME}/${PROMETHEUS_NAME}/" -i ${CONFIG_FILE}

    echo ""
    echo "Preparing htpasswd file"
    HTPASSWD_FILE=$(mktemp)
    chmod 666 ${HTPASSWD_FILE}
    echo "${HTPASSWD_FILE}"
    cp tests/configuration/htpasswd ${HTPASSWD_FILE}

    echo ""
    echo "Starting nginx container"
    docker rm -f ${NGINX_NAME}
    docker run --name ${NGINX_NAME} --net=${NETWORK_NAME} -d -p ${NGINX_PORT}:80 -v ${CONFIG_FILE}:/etc/nginx/nginx.conf:ro -v ${HTPASSWD_FILE}:/etc/nginx/.htpasswd:ro nginx

    echo ""
    echo "Waiting until nginx is up"
    until $(curl --output /dev/null --silent --fail http://localhost:${NGINX_PORT}/health); do
        printf '.'
        sleep 1
    done
}

function start_pushgateway() {
    echo ""
    echo "Starting pushgateway container"
    docker rm -f ${PUSHGATEWAY_NAME}
    docker run --name ${PUSHGATEWAY_NAME} --net=${NETWORK_NAME} -d -p ${PUSHGATEWAY_PORT}:9091 prom/pushgateway

    echo ""
    echo "Waiting until pushgateway is up"
    until $(curl --output /dev/null --silent --fail http://localhost:${PUSHGATEWAY_PORT}); do
        printf '.'
        sleep 1
    done
}

function start_prometheus() {
    echo ""
    echo "Creating configuration file"
    CONFIG_FILE=$(mktemp --suffix=.yml)
    chmod 666 ${CONFIG_FILE}
    echo "${CONFIG_FILE}"

    echo ""
    echo "Templating configuration file"
    sed -e "s/\${PUSHGATEWAY_NAME}/${PUSHGATEWAY_NAME}/" tests/configuration/prometheus.yml > ${CONFIG_FILE}

    echo ""
    echo "Starting prometheus container"
    docker rm -f ${PROMETHEUS_NAME}
    docker run --name ${PROMETHEUS_NAME} --net=${NETWORK_NAME} -d -p ${PROMETHEUS_PORT}:9090 -v ${CONFIG_FILE}:/etc/prometheus/prometheus.yml:ro prom/prometheus

    echo ""
    echo "Waiting until prometheus is up"
    until $(curl --output /dev/null --silent --fail http://localhost:${PROMETHEUS_PORT}); do
        printf '.'
        sleep 1
    done

    echo ""
    echo "Waiting until prometheus sees itself"
    QUERY_SCALAR_UP="scalar(up{instance=\"localhost:9090\"})"
    wait_for_metric "${QUERY_SCALAR_UP}" 1
    echo ""
}

function start_pushgateway() {
    echo ""
    echo "Starting pushgateway container"
    docker rm -f ${PUSHGATEWAY_NAME}
    docker run --name ${PUSHGATEWAY_NAME} --net=${NETWORK_NAME} -d -p ${PUSHGATEWAY_PORT}:9091 prom/pushgateway

    echo ""
    echo "Waiting until pushgateway is up"
    until $(curl --output /dev/null --silent --fail http://localhost:${PUSHGATEWAY_PORT}); do
        printf '.'
        sleep 1
    done
}

function start_icinga() {
    echo "Cleaning up old container..."
    docker rm -f icinga

    echo "Creating icinga container..."
    docker create --name icinga -p 80:80 -p 5665:5665 -h icinga2 --net=${NETWORK_NAME} -t jordan/icinga2:latest

    echo "Transfering monitoring scripts..."
    docker cp ${PLUGIN_SCRIPT} icinga:/usr/lib/nagios/plugins/check_prometheus_metric

    echo "Starting icinga..."
    docker start icinga

    echo "Waiting for icinga to generate files..."
    docker exec icinga /bin/bash -c "while ! [ -f /etc/icinga2/conf.d/services.conf ]; do printf '.'; sleep 1; done"
    echo ""

    echo "Transfering icinga configuration files..."
    docker cp tests/configuration/icinga.conf icinga:/etc/icinga2/conf.d/check_prometheus_metric.conf

    echo "Installing script dependencies..."
    docker exec icinga /bin/bash -c "apt-get update && apt-get install -y curl jq"

    echo "Fetching API password..."
    PASSWORD=$(docker exec icinga /bin/bash -c "cat /etc/icinga2/conf.d/api-users.conf | grep -o 'password = .*'| cut -f2 -d '\"'")
    echo "${PASSWORD}" 
    export "ICINGA_PASSWORD=${PASSWORD}"

    echo "Wait for icinga to be online..."
    # TODO: Actually check against the API
    sleep 10
}

function _fetch_service() {
    curl -s -k -u "root:${ICINGA_PASSWORD}" -H 'Accept: application/json' \
         -H 'X-HTTP-Method-Override: GET' \
         -X POST "https://localhost:${ICINGA_PORT}/v1/objects/services" \
         -d "{\"filter\": \"match(\\\"$1\\\",service.name)\"}"
}

function _order_recheck() {
    curl -s -k -u "root:${ICINGA_PASSWORD}" -H 'Accept: application/json' \
         -X POST "https://localhost:${ICINGA_PORT}/v1/actions/reschedule-check" \
         -d "{\"type\": \"Service\", \"filter\": \"service.name==\\\"$1\\\"\", \"force\": true}"
}

function recheck_service() {
    local _NOW
    local _RECHECK
    local _LAST_CHECKED
    local _KEEP_GOING="false"

    # Order a service update
    _RECHECK=$(_order_recheck $1)

    # Keep running until service is rechecked
    until [ "${_KEEP_GOING}" == "true" ]; do
        # Find out when we last checked the service
        _LAST_CHECKED=$(_fetch_service $1 | jq .[][0].attrs.last_check)
        _NOW=$(date +%s)
        # Keep going until last_checked is in the past
        _KEEP_GOING=$(echo "{\"last_checked\": ${_LAST_CHECKED}, \"now\": ${_NOW}}" | jq ".last_checked <= .now")
        printf '.'
        sleep 1
    done
}

function get_service_state() {
    _fetch_service $1 | jq .[][0].attrs.state
}
