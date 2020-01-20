#!/usr/bin/env bats

load test_config
PROMETHEUS_SERVER=http://localhost:${PROMETHEUS_PORT}

load test_utils

# Test comparisons
#-----------------
# Base-case
@test "Test -q 1 -w 2 -c 3" {
  OUTPUT="$(test_parameters '-q 1 -w 2 -c 3')"
  [ "${OUTPUT}" == "OK - tc is 1" ]
}
@test "Test -q 2 -w 2 -c 3" {
  OUTPUT="$(test_parameters '-q 2 -w 2 -c 3')"
  [ "${OUTPUT}" == "WARNING - tc is 2" ]
}
@test "Test -q 3 -w 2 -c 3" {
  OUTPUT="$(test_parameters '-q 3 -w 2 -c 3')"
  [ "${OUTPUT}" == "CRITICAL - tc is 3" ]
}
@test "Test -q 4 -w 2 -c 3" {
  OUTPUT="$(test_parameters '-q 4 -w 2 -c 3')"
  [ "${OUTPUT}" == "CRITICAL - tc is 4" ]
}

# Critical stronger than warning
@test "Test -q 1 -w 2 -c 2" {
  OUTPUT="$(test_parameters '-q 1 -w 2 -c 2')"
  [ "${OUTPUT}" == "OK - tc is 1" ]
}
@test "Test -q 2 -w 2 -c 2" {
  OUTPUT="$(test_parameters '-q 2 -w 2 -c 2')"
  [ "${OUTPUT}" == "CRITICAL - tc is 2" ]
}
@test "Test -q 3 -w 2 -c 2" {
  OUTPUT="$(test_parameters '-q 3 -w 2 -c 2')"
  [ "${OUTPUT}" == "CRITICAL - tc is 3" ]
}
@test "Test -q 4 -w 2 -c 2" {
  OUTPUT="$(test_parameters '-q 4 -w 2 -c 2')"
  [ "${OUTPUT}" == "CRITICAL - tc is 4" ]
}

# Comparison method (gt)
@test "Test -q 1 -w 2 -c 3 -m gt" {
  OUTPUT="$(test_parameters '-q 1 -w 2 -c 3 -m gt')"
  [ "${OUTPUT}" == "OK - tc is 1" ]
}
@test "Test -q 2 -w 2 -c 3 -m gt" {
  OUTPUT="$(test_parameters '-q 2 -w 2 -c 3 -m gt')"
  [ "${OUTPUT}" == "OK - tc is 2" ]
}
@test "Test -q 3 -w 2 -c 3 -m gt" {
  OUTPUT="$(test_parameters '-q 3 -w 2 -c 3 -m gt')"
  [ "${OUTPUT}" == "WARNING - tc is 3" ]
}
@test "Test -q 4 -w 2 -c 3 -m gt" {
  OUTPUT="$(test_parameters '-q 4 -w 2 -c 3 -m gt')"
  [ "${OUTPUT}" == "CRITICAL - tc is 4" ]
}

# Comparison method (ge, default)
@test "Test -q 1 -w 2 -c 3 -m ge" {
  OUTPUT="$(test_parameters '-q 1 -w 2 -c 3 -m ge')"
  [ "${OUTPUT}" == "OK - tc is 1" ]
}
@test "Test -q 2 -w 2 -c 3 -m ge" {
  OUTPUT="$(test_parameters '-q 2 -w 2 -c 3 -m ge')"
  [ "${OUTPUT}" == "WARNING - tc is 2" ]
}
@test "Test -q 3 -w 2 -c 3 -m ge" {
  OUTPUT="$(test_parameters '-q 3 -w 2 -c 3 -m ge')"
  [ "${OUTPUT}" == "CRITICAL - tc is 3" ]
}
@test "Test -q 4 -w 2 -c 3 -m ge" {
  OUTPUT="$(test_parameters '-q 4 -w 2 -c 3 -m ge')"
  [ "${OUTPUT}" == "CRITICAL - tc is 4" ]
}

# Comparison method (lt, default)
@test "Test -q 1 -w 2 -c 3 -m lt" {
  OUTPUT="$(test_parameters '-q 1 -w 2 -c 3 -m lt')"
  [ "${OUTPUT}" == "CRITICAL - tc is 1" ]
}
@test "Test -q 2 -w 2 -c 3 -m lt" {
  OUTPUT="$(test_parameters '-q 2 -w 2 -c 3 -m lt')"
  [ "${OUTPUT}" == "CRITICAL - tc is 2" ]
}
@test "Test -q 3 -w 2 -c 3 -m lt" {
  OUTPUT="$(test_parameters '-q 3 -w 2 -c 3 -m lt')"
  [ "${OUTPUT}" == "OK - tc is 3" ]
}
@test "Test -q 4 -w 2 -c 3 -m lt" {
  OUTPUT="$(test_parameters '-q 4 -w 2 -c 3 -m lt')"
  [ "${OUTPUT}" == "OK - tc is 4" ]
}

# Comparison method (le, default)
@test "Test -q 1 -w 2 -c 3 -m le" {
  OUTPUT="$(test_parameters '-q 1 -w 2 -c 3 -m le')"
  [ "${OUTPUT}" == "CRITICAL - tc is 1" ]
}
@test "Test -q 2 -w 2 -c 3 -m le" {
  OUTPUT="$(test_parameters '-q 2 -w 2 -c 3 -m le')"
  [ "${OUTPUT}" == "CRITICAL - tc is 2" ]
}
@test "Test -q 3 -w 2 -c 3 -m le" {
  OUTPUT="$(test_parameters '-q 3 -w 2 -c 3 -m le')"
  [ "${OUTPUT}" == "CRITICAL - tc is 3" ]
}
@test "Test -q 4 -w 2 -c 3 -m le" {
  OUTPUT="$(test_parameters '-q 4 -w 2 -c 3 -m le')"
  [ "${OUTPUT}" == "OK - tc is 4" ]
}

# Comparison method (eq, default)
@test "Test -q 1 -w 2 -c 3 -m eq" {
  OUTPUT="$(test_parameters '-q 1 -w 2 -c 3 -m eq')"
  [ "${OUTPUT}" == "OK - tc is 1" ]
}
@test "Test -q 2 -w 2 -c 3 -m eq" {
  OUTPUT="$(test_parameters '-q 2 -w 2 -c 3 -m eq')"
  [ "${OUTPUT}" == "WARNING - tc is 2" ]
}
@test "Test -q 3 -w 2 -c 3 -m eq" {
  OUTPUT="$(test_parameters '-q 3 -w 2 -c 3 -m eq')"
  [ "${OUTPUT}" == "CRITICAL - tc is 3" ]
}
@test "Test -q 4 -w 2 -c 3 -m eq" {
  OUTPUT="$(test_parameters '-q 4 -w 2 -c 3 -m eq')"
  [ "${OUTPUT}" == "OK - tc is 4" ]
}

# Comparison method (ne, default)
@test "Test -q 1 -w 2 -c 3 -m ne" {
  OUTPUT="$(test_parameters '-q 1 -w 2 -c 3 -m ne')"
  [ "${OUTPUT}" == "CRITICAL - tc is 1" ]
}
@test "Test -q 2 -w 2 -c 3 -m ne" {
  OUTPUT="$(test_parameters '-q 2 -w 2 -c 3 -m ne')"
  [ "${OUTPUT}" == "CRITICAL - tc is 2" ]
}
@test "Test -q 3 -w 2 -c 3 -m ne" {
  OUTPUT="$(test_parameters '-q 3 -w 2 -c 3 -m ne')"
  [ "${OUTPUT}" == "WARNING - tc is 3" ]
}
@test "Test -q 4 -w 2 -c 3 -m ne" {
  OUTPUT="$(test_parameters '-q 4 -w 2 -c 3 -m ne')"
  [ "${OUTPUT}" == "CRITICAL - tc is 4" ]
}

# Invalid cases
# Missing argument
@test "Test -q 1 -w 2" {
  OUTPUT="$(test_parameters '-q 1 -w 2')"
  [ "${OUTPUT}" == "UNKNOWN - missing required option" ]
}
@test "Test -q 1 -c 3" {
  OUTPUT="$(test_parameters '-q 1 -c 3')"
  [ "${OUTPUT}" == "UNKNOWN - missing required option" ]
}

# Invalid warning / critical argument
@test "Test -q 1 -w 2 -c -1" {
  OUTPUT="$(test_parameters '-q 1 -w 2 -c -1')"
  [ "${OUTPUT}" == "UNKNOWN - -c CRITICAL_LEVEL requires an integer or interval" ]
}
@test "Test -q 1 -w -1 -c 3" {
  OUTPUT="$(test_parameters '-q 1 -w -1 -c 3')"
  [ "${OUTPUT}" == "UNKNOWN - -w WARNING_LEVEL requires an integer or interval" ]
}
@test "Test -q 1 -w 2 -c one" {
  OUTPUT="$(test_parameters '-q 1 -w 2 -c one')"
  [ "${OUTPUT}" == "UNKNOWN - -c CRITICAL_LEVEL requires an integer or interval" ]
}
@test "Test -q 1 -w one -c 3" {
  OUTPUT="$(test_parameters '-q 1 -w one -c 3')"
  [ "${OUTPUT}" == "UNKNOWN - -w WARNING_LEVEL requires an integer or interval" ]
}

# Invalid comparision operator
@test "Test -q 1 -w 2 -c 3 -m above" {
  OUTPUT="$(test_parameters '-q 1 -w 2 -c 3 -m above')"
  [ "${OUTPUT}" == "UNKNOWN - invalid comparison method: above" ]
}
@test "Test -q 1 -w 2 -c 3 -m below" {
  OUTPUT="$(test_parameters '-q 1 -w 2 -c 3 -m below')"
  [ "${OUTPUT}" == "UNKNOWN - invalid comparison method: below" ]
}
