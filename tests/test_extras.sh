#!/bin/bash
set +x

PLUGIN_SCRIPT=$1
PROMETHEUS_PORT=$2
PUSHGATEWAY_PORT=$3

PROMETHEUS_SERVER=http://localhost:${PROMETHEUS_PORT}

source tests/utils.sh

QUERY_SCALAR_UP="scalar(up{instance=\"localhost:9090\"})"
QUERY_VECTOR_UP="up{instance=\"localhost:9090\"}"

# Parameterized test-cases, format:
# commandline-parameters #expected-output
TESTS="
# Base-case
-q 1 -w 2 -c 3 #OK - tc is 1
-q 2 -w 2 -c 3 #WARNING - tc is 2
-q 3 -w 2 -c 3 #CRITICAL - tc is 3
-q 4 -w 2 -c 3 #CRITICAL - tc is 4

# With perfdata
-q 1 -w 2 -c 3 -p #OK - tc is 1 | query_result=1
-q 2 -w 2 -c 3 -p #WARNING - tc is 2 | query_result=2
-q 3 -w 2 -c 3 -p #CRITICAL - tc is 3 | query_result=3
-q 4 -w 2 -c 3 -p #CRITICAL - tc is 4 | query_result=4

# With extra metric infomation (scalars have UNKNOWN)
-q 1 -w 2 -c 3 -i #OK - tc is 1: UNKNOWN
-q 2 -w 2 -c 3 -i #WARNING - tc is 2: UNKNOWN
-q 3 -w 2 -c 3 -i #CRITICAL - tc is 3: UNKNOWN
-q 4 -w 2 -c 3 -i #CRITICAL - tc is 4: UNKNOWN

# With extra metric infomation (vectors have extras)
-q vector(1) -w 2 -c 3 -i -t vector #OK - tc is 1: {}
-q vector(2) -w 2 -c 3 -i -t vector #WARNING - tc is 2: {}
-q vector(3) -w 2 -c 3 -i -t vector #CRITICAL - tc is 3: {}
-q vector(4) -w 2 -c 3 -i -t vector #CRITICAL - tc is 4: {}

# With both perfdata and extra metric information (scalars)
-q 1 -w 2 -c 3 -i -p #OK - tc is 1: UNKNOWN | query_result=1
-q 2 -w 2 -c 3 -i -p #WARNING - tc is 2: UNKNOWN | query_result=2
-q 3 -w 2 -c 3 -i -p #CRITICAL - tc is 3: UNKNOWN | query_result=3
-q 4 -w 2 -c 3 -i -p #CRITICAL - tc is 4: UNKNOWN | query_result=4

# With both perfdata and extra metric information (vectors)
-q vector(1) -w 2 -c 3 -i -p -t vector #OK - tc is 1: {} | query_result=1
-q vector(2) -w 2 -c 3 -i -p -t vector #WARNING - tc is 2: {} | query_result=2
-q vector(3) -w 2 -c 3 -i -p -t vector #CRITICAL - tc is 3: {} | query_result=3
-q vector(4) -w 2 -c 3 -i -p -t vector #CRITICAL - tc is 4: {} | query_result=4

# Actual queries
#---------------
# With extra metric infomation (actual scalar query)
-q ${QUERY_SCALAR_UP} -w 2 -c 3 -i #OK - tc is 1: UNKNOWN

# With extra metric infomation (actual vector query)
-q ${QUERY_VECTOR_UP} -w 2 -c 3 -i -t vector #OK - tc is 1: { __name__: up, instance: localhost:9090, job: prometheus }

# TODO: Produce better warning when scalar is expected and vector is returned
# Scalar query on non-scalar and vice versa
-q vector(1) -w 2 -c 3 #UNKNOWN - unable to parse prometheus response
-q vector(1) -w 2 -c 3 -t vector #OK - tc is 1
-q vector(1) -w 2 -c 3 -t scalar #UNKNOWN - unable to parse prometheus response
-q 1 -w 2 -c 3 #OK - tc is 1
-q 1 -w 2 -c 3 -t vector #UNKNOWN - unable to parse prometheus response
-q 1 -w 2 -c 3 -t scalar #OK - tc is 1
-q scalar(vector(1)) -w 2 -c 3 #OK - tc is 1
-q scalar(vector(1)) -w 2 -c 3 -t vector #UNKNOWN - unable to parse prometheus response
-q scalar(vector(1)) -w 2 -c 3 -t scalar #OK - tc is 1
"
# Get rid of empty lines and comments
TESTS=$(echo "${TESTS}" | sed '/^$/d' | sed '/^#/d')
# Loop through each test-case
parameterized_tests "${TESTS}"

echo ""
echo "$((TOTAL_TESTS - TOTAL_FAILS)) / ${TOTAL_TESTS}"
exit ${TOTAL_FAILS}
