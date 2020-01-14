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
-q 1 -w 2: -c 3: #OK - tc is 1
-q 2 -w 2: -c 3: #WARNING - tc is 2
-q 3 -w 2: -c 3: #CRITICAL - tc is 3
-q 4 -w 2: -c 3: #CRITICAL - tc is 4

# Critical stronger than warning
-q 1 -w 2: -c 2: #OK - tc is 1
-q 2 -w 2: -c 2: #CRITICAL - tc is 2
-q 3 -w 2: -c 2: #CRITICAL - tc is 3
-q 4 -w 2: -c 2: #CRITICAL - tc is 4

# Comparison method (gt)
-q 1 -w 2: -c 3: -m gt #OK - tc is 1
-q 2 -w 2: -c 3: -m gt #OK - tc is 2
-q 3 -w 2: -c 3: -m gt #WARNING - tc is 3
-q 4 -w 2: -c 3: -m gt #CRITICAL - tc is 4

# Comparison method (ge, default)
-q 1 -w 2: -c 3: -m ge #OK - tc is 1
-q 2 -w 2: -c 3: -m ge #WARNING - tc is 2
-q 3 -w 2: -c 3: -m ge #CRITICAL - tc is 3
-q 4 -w 2: -c 3: -m ge #CRITICAL - tc is 4

# Comparison method (lt, default)
-q 1 -w 2: -c 3: -m lt #CRITICAL - tc is 1
-q 2 -w 2: -c 3: -m lt #CRITICAL - tc is 2
-q 3 -w 2: -c 3: -m lt #OK - tc is 3
-q 4 -w 2: -c 3: -m lt #OK - tc is 4

# Comparison method (le, default)
-q 1 -w 2: -c 3: -m le #CRITICAL - tc is 1
-q 2 -w 2: -c 3: -m le #CRITICAL - tc is 2
-q 3 -w 2: -c 3: -m le #CRITICAL - tc is 3
-q 4 -w 2: -c 3: -m le #OK - tc is 4

# Comparison method (eq, default)
-q 1 -w 2: -c 3: -m eq #OK - tc is 1
-q 2 -w 2: -c 3: -m eq #WARNING - tc is 2
-q 3 -w 2: -c 3: -m eq #CRITICAL - tc is 3
-q 4 -w 2: -c 3: -m eq #OK - tc is 4

# Comparison method (ne, default)
-q 1 -w 2: -c 3: -m ne #CRITICAL - tc is 1
-q 2 -w 2: -c 3: -m ne #CRITICAL - tc is 2
-q 3 -w 2: -c 3: -m ne #WARNING - tc is 3
-q 4 -w 2: -c 3: -m ne #CRITICAL - tc is 4

# Invalid cases
# Missing argument
-q 1 -w 2: #UNKNOWN - missing required option
-q 1 -c 3: #UNKNOWN - missing required option
# Invalid warning / critical argument
-q 1 -w 2: -c -1: #UNKNOWN - -c CRITICAL_LEVEL requires an integer or interval
-q 1 -w -1: -c 3: #UNKNOWN - -w WARNING_LEVEL requires an integer or interval
-q 1 -w 2: -c one: #UNKNOWN - -c CRITICAL_LEVEL requires an integer or interval
-q 1 -w one: -c 3: #UNKNOWN - -w WARNING_LEVEL requires an integer or interval
# Invalid comparision operator
-q 1 -w 2: -c 3: -m above #UNKNOWN - invalid comparison method: above
-q 1 -w 2: -c 3: -m below #UNKNOWN - invalid comparison method: below
"
# Get rid of empty lines and comments
TESTS=$(echo "${TESTS}" | sed '/^$/d' | sed '/^#/d')
# Loop through each test-case
parameterized_tests "${TESTS}"

echo ""
echo "$((TOTAL_TESTS - TOTAL_FAILS)) / ${TOTAL_TESTS}"
exit ${TOTAL_FAILS}
