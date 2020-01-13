#!/bin/bash
set +x

PLUGIN_SCRIPT=$1
PROMETHEUS_PORT=$2
PUSHGATEWAY_PORT=$3

PROMETHEUS_SERVER=http://localhost:${PROMETHEUS_PORT}

source tests/utils.sh

# Parameterized test-cases, format:
# commandline-parameters #expected-output
TESTS="
# Base-case
-q 1 -w 2 -c 3 #OK - tc is 1
-q 1 -w 2 -c 3 -O #OK - tc is 1

# NaN as return
-q NaN -w 2 -c 3 #UNKNOWN - unable to parse prometheus response
-q NaN -w 2 -c 3 -O #OK - tc is NaN
"
# Get rid of empty lines and comments
TESTS=$(echo "${TESTS}" | sed '/^$/d' | sed '/^#/d')
# Loop through each test-case
parameterized_tests "${TESTS}"

echo ""
echo "$((TOTAL_TESTS - TOTAL_FAILS)) / ${TOTAL_TESTS}"
exit ${TOTAL_FAILS}
