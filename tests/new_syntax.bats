#!/usr/bin/env bats

load test_config
PROMETHEUS_SERVER=http://localhost:${PROMETHEUS_PORT}

load test_utils

@test "--- ${BATS_TEST_FILENAME} ---" {
  true
}
# Test comparisons
#-----------------
# Base-case
@test "Test -q -1 -w 2 -c 3" {
  OUTPUT="$(test_parameters '-q -1 -w 2 -c 3')"
  [ "${OUTPUT}" == "CRITICAL - tc is -1" ]
}
@test "Test -q 0 -w 2 -c 3" {
  OUTPUT="$(test_parameters '-q 0 -w 2 -c 3')"
  [ "${OUTPUT}" == "OK - tc is 0" ]
}
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
@test "Test -q -1 -w 2 -c 2" {
  OUTPUT="$(test_parameters '-q -1 -w 2 -c 2')"
  [ "${OUTPUT}" == "CRITICAL - tc is -1" ]
}
@test "Test -q 0 -w 2 -c 2" {
  OUTPUT="$(test_parameters '-q 0 -w 2 -c 2')"
  [ "${OUTPUT}" == "OK - tc is 0" ]
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

# Comma-numbers
@test "Test -q 1.9 -w 2 -c 3" {
  OUTPUT="$(test_parameters '-q 1.9 -w 2 -c 3')"
  [ "${OUTPUT}" == "OK - tc is 1.9" ]
}
@test "Test -q 2.9 -w 2 -c 3" {
  OUTPUT="$(test_parameters '-q 2.9 -w 2 -c 3')"
  [ "${OUTPUT}" == "WARNING - tc is 2.9" ]
}

# Edge-cases
@test "Test -q -0 -w 2 -c 3" {
  OUTPUT="$(test_parameters '-q -0 -w 2 -c 3')"
  [ "${OUTPUT}" == "OK - tc is -0" ]
}
@test "Test -q -0.0 -w 2 -c 3" {
  OUTPUT="$(test_parameters '-q -0.0 -w 2 -c 3')"
  [ "${OUTPUT}" == "OK - tc is -0" ]
}
