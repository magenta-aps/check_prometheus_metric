#!/bin/bash
set +x

PLUGIN_SCRIPT=$1
PROMETHEUS_PORT=$2
PUSHGATEWAY_PORT=$3

source tests/utils.sh

# is_integer
RESULT=$(bash -c "source ${PLUGIN_SCRIPT}; source tests/utils.sh; print_exit 'is_integer 1'")
EXPECTED="0"
check "$RESULT" "$EXPECTED"

RESULT=$(bash -c "source ${PLUGIN_SCRIPT}; source tests/utils.sh; print_exit 'is_integer 1256'")
EXPECTED="0"
check "$RESULT" "$EXPECTED"

RESULT=$(bash -c "source ${PLUGIN_SCRIPT}; source tests/utils.sh; print_exit 'is_integer one'")
EXPECTED="1"
check "$RESULT" "$EXPECTED"

RESULT=$(bash -c "source ${PLUGIN_SCRIPT}; source tests/utils.sh; print_exit 'is_integer -1'")
EXPECTED="1"
check "$RESULT" "$EXPECTED"

# is_interval
RESULT=$(bash -c "source ${PLUGIN_SCRIPT}; source tests/utils.sh; print_exit 'is_interval 1:3'")
EXPECTED="0"
check "$RESULT" "$EXPECTED"

RESULT=$(bash -c "source ${PLUGIN_SCRIPT}; source tests/utils.sh; print_exit 'is_interval 1:'")
EXPECTED="0"
check "$RESULT" "$EXPECTED"

RESULT=$(bash -c "source ${PLUGIN_SCRIPT}; source tests/utils.sh; print_exit 'is_interval :3'")
EXPECTED="0"
check "$RESULT" "$EXPECTED"

RESULT=$(bash -c "source ${PLUGIN_SCRIPT}; source tests/utils.sh; print_exit 'is_interval :'")
EXPECTED="0"
check "$RESULT" "$EXPECTED"

RESULT=$(bash -c "source ${PLUGIN_SCRIPT}; source tests/utils.sh; print_exit 'is_interval -1:'")
EXPECTED="1"
check "$RESULT" "$EXPECTED"

RESULT=$(bash -c "source ${PLUGIN_SCRIPT}; source tests/utils.sh; print_exit 'is_interval :-1'")
EXPECTED="1"
check "$RESULT" "$EXPECTED"

RESULT=$(bash -c "source ${PLUGIN_SCRIPT}; source tests/utils.sh; print_exit 'is_interval one:'")
EXPECTED="1"
check "$RESULT" "$EXPECTED"

RESULT=$(bash -c "source ${PLUGIN_SCRIPT}; source tests/utils.sh; print_exit 'is_interval 1'")
EXPECTED="1"
check "$RESULT" "$EXPECTED"

echo ""
echo "$((TOTAL_TESTS - TOTAL_FAILS)) / ${TOTAL_TESTS}"
exit ${TOTAL_FAILS}
