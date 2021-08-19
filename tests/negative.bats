#!/usr/bin/env bats

PROMETHEUS_SERVER=http://localhost:${PROMETHEUS_PORT}

load test_utils

@test "--- ${BATS_TEST_FILENAME} ---" {
  true
}
# Base-case
@test "Test -q negative -w 2 -c 3" {
  OUTPUT="$(test_parameters '-q negative -w ~:2 -c ~:3')"
  echo ${OUTPUT}
  [ "${OUTPUT}" == "OK - tc is -11" ]
}
@test "Test -q scalar(negative) -w 2 -c 3" {
  OUTPUT="$(test_parameters '-q scalar(negative) -w ~:2 -c ~:3')"
  echo ${OUTPUT}
  [ "${OUTPUT}" == "OK - tc is -11" ]
}
