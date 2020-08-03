#!/usr/bin/env bats

PROMETHEUS_SERVER=http://localhost:${NGINX_PORT}/

UNABLE_TO_QUERY="UNKNOWN - unable to query prometheus endpoint!"
BASIC_AUTH_PARAMS="-C --user -C admin:admin"


load test_utils

@test "--- ${BATS_TEST_FILENAME} ---" {
  true
}
# Failing due to basic auth
@test "Test without basic auth -q 1 -w 2 -c 3" {
  OUTPUT="$(test_parameters '-q 1 -w 2 -c 3')"
  echo $OUTPUT
  [ "${OUTPUT}" == "${UNABLE_TO_QUERY}" ]
}
@test "Test without basic auth -q 2 -w 2 -c 3" {
  OUTPUT="$(test_parameters '-q 2 -w 2 -c 3')"
  [ "${OUTPUT}" == "${UNABLE_TO_QUERY}" ]
}
@test "Test without basic auth -q 3 -w 2 -c 3" {
  OUTPUT="$(test_parameters '-q 3 -w 2 -c 3')"
  [ "${OUTPUT}" == "${UNABLE_TO_QUERY}" ]
}
@test "Test without basic auth -q 4 -w 2 -c 3" {
  OUTPUT="$(test_parameters '-q 4 -w 2 -c 3')"
  [ "${OUTPUT}" == "${UNABLE_TO_QUERY}" ]
}

# Passing with basic auth
@test "Test with basic auth -q 1 -w 2 -c 3" {
  OUTPUT="$(test_parameters "${BASIC_AUTH_PARAMS} -q 1 -w 2 -c 3")"
  [ "${OUTPUT}" == "OK - tc is 1" ]
}
@test "Test with basic auth -q 2 -w 2 -c 3" {
  OUTPUT="$(test_parameters "${BASIC_AUTH_PARAMS} -q 2 -w 2 -c 3")"
  [ "${OUTPUT}" == "WARNING - tc is 2" ]
}
@test "Test with basic auth -q 3 -w 2 -c 3" {
  OUTPUT="$(test_parameters "${BASIC_AUTH_PARAMS} -q 3 -w 2 -c 3")"
  [ "${OUTPUT}" == "CRITICAL - tc is 3" ]
}
@test "Test with basic auth -q 4 -w 2 -c 3" {
  OUTPUT="$(test_parameters "${BASIC_AUTH_PARAMS} -q 4 -w 2 -c 3")"
  [ "${OUTPUT}" == "CRITICAL - tc is 4" ]
}
