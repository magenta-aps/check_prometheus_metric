#!/usr/bin/env bats

load test_config
PROMETHEUS_SERVER=http://localhost:${PROMETHEUS_PORT}
QUERY_SCALAR_UP="scalar(up{instance=\"localhost:9090\"})"
QUERY_VECTOR_UP="up{instance=\"localhost:9090\"}"

load test_utils

# Base-case
@test "Test -q 1 -w 2 -c 3" {
  OUTPUT="$(test_parameters '-q 1 -w 2 -c 3')"
  [ "${OUTPUT}" == "OK - tc is 1" ]
}
@test "Test -q 1 -w 2 -c 3 -O" {
  OUTPUT="$(test_parameters '-q 1 -w 2 -c 3 -O')"
  [ "${OUTPUT}" == "OK - tc is 1" ]
}

# NaN as return
@test "Test -q NaN -w 2 -c 3" {
  OUTPUT="$(test_parameters '-q NaN -w 2 -c 3')"
  [ "${OUTPUT}" == "UNKNOWN - unable to parse prometheus response" ]
}
@test "Test -q NaN -w 2 -c 3 -O" {
  OUTPUT="$(test_parameters '-q NaN -w 2 -c 3 -O')"
  [ "${OUTPUT}" == "OK - tc is NaN" ]
}
