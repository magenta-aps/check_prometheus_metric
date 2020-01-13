#!/bin/bash
set +x

PLUGIN_SCRIPT=$1
PROMETHEUS_PORT=$2
PUSHGATEWAY_PORT=$3

PROMETHEUS_SERVER=http://localhost:${PROMETHEUS_PORT}

QUERY_SCALAR_UP="scalar(up{instance=\"localhost:9090\"})"
QUERY_VECTOR_UP="up{instance=\"localhost:9090\"}"

TOTAL_TESTS=0
TOTAL_FAILS=0
function check() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if [ "$1" != "$2" ]; then
        TOTAL_FAILS=$((TOTAL_FAILS + 1))
        echo -e "x\c"
    else
        echo -e ".\c"
    fi
}

RESULT=$(bash ${PLUGIN_SCRIPT} -H "${PROMETHEUS_SERVER}" -q $QUERY_SCALAR_UP -w 1 -c 1 -n $QUERY_SCALAR_UP -m lt)
EXPECTED="OK - ${QUERY_SCALAR_UP} is 1"
check "$RESULT" "$EXPECTED"

RESULT=$(bash ${PLUGIN_SCRIPT} -H "${PROMETHEUS_SERVER}" -q $QUERY_SCALAR_UP -w 1 -c 1 -n $QUERY_SCALAR_UP -m lt -i)
EXPECTED="OK - ${QUERY_SCALAR_UP} is 1: UNKNOWN"
check "$RESULT" "$EXPECTED"

RESULT=$(bash ${PLUGIN_SCRIPT} -H "${PROMETHEUS_SERVER}" -q $QUERY_VECTOR_UP -w 1 -c 1 -n $QUERY_VECTOR_UP -m lt -t vector)
EXPECTED="OK - ${QUERY_VECTOR_UP} is 1"
check "$RESULT" "$EXPECTED"

RESULT=$(bash ${PLUGIN_SCRIPT} -H "${PROMETHEUS_SERVER}" -q $QUERY_VECTOR_UP -w 1 -c 1 -n $QUERY_VECTOR_UP -m lt -t vector -i)
EXPECTED="OK - ${QUERY_VECTOR_UP} is 1: { __name__: up, instance: localhost:9090, job: prometheus }"
check "$RESULT" "$EXPECTED"

echo ""
echo "$((TOTAL_TESTS - TOTAL_FAILS)) / ${TOTAL_TESTS}"
exit ${TOTAL_FAILS}
