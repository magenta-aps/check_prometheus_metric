#!/usr/bin/env bats

load test_config
PROMETHEUS_SERVER=http://localhost:${PROMETHEUS_PORT}
QUERY_SCALAR_UP="scalar(up{instance=\"localhost:9090\"})"
QUERY_VECTOR_UP="up{instance=\"localhost:9090\"}"

load test_utils

@test "--- ${BATS_TEST_FILENAME} ---" {
  true
}
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

# With perfdata
@test "Test -q 1 -w 2 -c 3 -p" {
  OUTPUT="$(test_parameters '-q 1 -w 2 -c 3 -p')"
  [ "${OUTPUT}" == "OK - tc is 1 | query_result=1" ]
}
@test "Test -q 2 -w 2 -c 3 -p" {
  OUTPUT="$(test_parameters '-q 2 -w 2 -c 3 -p')"
  [ "${OUTPUT}" == "WARNING - tc is 2 | query_result=2" ]
}
@test "Test -q 3 -w 2 -c 3 -p" {
  OUTPUT="$(test_parameters '-q 3 -w 2 -c 3 -p')"
  [ "${OUTPUT}" == "CRITICAL - tc is 3 | query_result=3" ]
}
@test "Test -q 4 -w 2 -c 3 -p" {
  OUTPUT="$(test_parameters '-q 4 -w 2 -c 3 -p')"
  [ "${OUTPUT}" == "CRITICAL - tc is 4 | query_result=4" ]
}

# With extra metric infomation (scalars have UNKNOWN)
@test "Test -q 1 -w 2 -c 3 -i" {
  OUTPUT="$(test_parameters '-q 1 -w 2 -c 3 -i')"
  [ "${OUTPUT}" == "OK - tc is 1: UNKNOWN" ]
}
@test "Test -q 2 -w 2 -c 3 -i" {
  OUTPUT="$(test_parameters '-q 2 -w 2 -c 3 -i')"
  [ "${OUTPUT}" == "WARNING - tc is 2: UNKNOWN" ]
}
@test "Test -q 3 -w 2 -c 3 -i" {
  OUTPUT="$(test_parameters '-q 3 -w 2 -c 3 -i')"
  [ "${OUTPUT}" == "CRITICAL - tc is 3: UNKNOWN" ]
}
@test "Test -q 4 -w 2 -c 3 -i" {
  OUTPUT="$(test_parameters '-q 4 -w 2 -c 3 -i')"
  [ "${OUTPUT}" == "CRITICAL - tc is 4: UNKNOWN" ]
}

# With extra metric infomation (vectors have extras)
@test "Test -q vector(1) -w 2 -c 3 -i" {
  OUTPUT="$(test_parameters '-q vector(1) -w 2 -c 3 -i')"
  [ "${OUTPUT}" == "OK - tc is 1: {}" ]
}
@test "Test -q vector(2) -w 2 -c 3 -i" {
  OUTPUT="$(test_parameters '-q vector(2) -w 2 -c 3 -i')"
  [ "${OUTPUT}" == "WARNING - tc is 2: {}" ]
}
@test "Test -q vector(3) -w 2 -c 3 -i" {
  OUTPUT="$(test_parameters '-q vector(3) -w 2 -c 3 -i')"
  [ "${OUTPUT}" == "CRITICAL - tc is 3: {}" ]
}
@test "Test -q vector(4) -w 2 -c 3 -i" {
  OUTPUT="$(test_parameters '-q vector(4) -w 2 -c 3 -i')"
  [ "${OUTPUT}" == "CRITICAL - tc is 4: {}" ]
}

# With both perfdata and extra metric information (scalars)
@test "Test -q 1 -w 2 -c 3 -i -p" {
  OUTPUT="$(test_parameters '-q 1 -w 2 -c 3 -i -p')"
  [ "${OUTPUT}" == "OK - tc is 1: UNKNOWN | query_result=1" ]
}
@test "Test -q 2 -w 2 -c 3 -i -p" {
  OUTPUT="$(test_parameters '-q 2 -w 2 -c 3 -i -p')"
  [ "${OUTPUT}" == "WARNING - tc is 2: UNKNOWN | query_result=2" ]
}
@test "Test -q 3 -w 2 -c 3 -i -p" {
  OUTPUT="$(test_parameters '-q 3 -w 2 -c 3 -i -p')"
  [ "${OUTPUT}" == "CRITICAL - tc is 3: UNKNOWN | query_result=3" ]
}
@test "Test -q 4 -w 2 -c 3 -i -p" {
  OUTPUT="$(test_parameters '-q 4 -w 2 -c 3 -i -p')"
  [ "${OUTPUT}" == "CRITICAL - tc is 4: UNKNOWN | query_result=4" ]
}

# With both perfdata and extra metric information (vectors)
@test "Test -q vector(1) -w 2 -c 3 -i -p" {
  OUTPUT="$(test_parameters '-q vector(1) -w 2 -c 3 -i -p')"
  [ "${OUTPUT}" == "OK - tc is 1: {} | query_result=1" ]
}
@test "Test -q vector(2) -w 2 -c 3 -i -p" {
  OUTPUT="$(test_parameters '-q vector(2) -w 2 -c 3 -i -p')"
  [ "${OUTPUT}" == "WARNING - tc is 2: {} | query_result=2" ]
}
@test "Test -q vector(3) -w 2 -c 3 -i -p" {
  OUTPUT="$(test_parameters '-q vector(3) -w 2 -c 3 -i -p')"
  [ "${OUTPUT}" == "CRITICAL - tc is 3: {} | query_result=3" ]
}
@test "Test -q vector(4) -w 2 -c 3 -i -p" {
  OUTPUT="$(test_parameters '-q vector(4) -w 2 -c 3 -i -p')"
  [ "${OUTPUT}" == "CRITICAL - tc is 4: {} | query_result=4" ]
}

# Actual queries
#---------------
# With extra metric infomation (actual scalar query)
@test "Test -q ${QUERY_SCALAR_UP} -w 2 -c 3 -i" {
  OUTPUT="$(test_parameters '-q ${QUERY_SCALAR_UP} -w 2 -c 3 -i')"
  [ "${OUTPUT}" == "OK - tc is 1: UNKNOWN" ]
}

# With extra metric infomation (actual vector query)
@test "Test -q ${QUERY_VECTOR_UP} -w 2 -c 3 -i" {
  OUTPUT="$(test_parameters '-q ${QUERY_VECTOR_UP} -w 2 -c 3 -i')"
  [ "${OUTPUT}" == "OK - tc is 1: { __name__: up, instance: localhost:9090, job: prometheus }" ]
}

# Vector autodetected
@test "Test -q vector(1) -w 2 -c 3" {
  OUTPUT="$(test_parameters '-q vector(1) -w 2 -c 3')"
  [ "${OUTPUT}" == "OK - tc is 1" ]
}
@test "Test -q vector(1) -w 2 -c 3 -t vector" {
  OUTPUT="$(test_parameters '-q vector(1) -w 2 -c 3 -t vector')"
  [ "${OUTPUT}" == "UNKNOWN - deprecated argument provided: -t vector" ]
}
@test "Test -q vector(1) -w 2 -c 3 -t scalar" {
  OUTPUT="$(test_parameters '-q vector(1) -w 2 -c 3 -t scalar')"
  [ "${OUTPUT}" == "UNKNOWN - deprecated argument provided: -t scalar" ]
}

# Scalar autodetected
@test "Test -q 1 -w 2 -c 3" {
  OUTPUT="$(test_parameters '-q 1 -w 2 -c 3')"
  [ "${OUTPUT}" == "OK - tc is 1" ]
}
@test "Test -q 1 -w 2 -c 3 -t vector" {
  OUTPUT="$(test_parameters '-q 1 -w 2 -c 3 -t vector')"
  [ "${OUTPUT}" == "UNKNOWN - deprecated argument provided: -t vector" ]
}
@test "Test -q 1 -w 2 -c 3 -t scalar" {
  OUTPUT="$(test_parameters '-q 1 -w 2 -c 3 -t scalar')"
  [ "${OUTPUT}" == "UNKNOWN - deprecated argument provided: -t scalar" ]
}

# Scalar autodetected
@test "Test -q scalar(vector(1)) -w 2 -c 3" {
  OUTPUT="$(test_parameters '-q scalar(vector(1)) -w 2 -c 3')"
  [ "${OUTPUT}" == "OK - tc is 1" ]
}
@test "Test -q scalar(vector(1)) -w 2 -c 3 -t vector" {
  OUTPUT="${test_parameters '-q scalar(vector(1) -w 2 -c 3 -t vector')"
  [ "$OUTPUT}" == "UNKNOWN - deprecated argument provided: -t vector"
}
@test "Test -q scalar(vector(1)) -w 2 -c 3 -t scalar" {
  OUTPUT="$(test_parameters '-q scalar(vector(1)) -w 2 -c 3 -t scalar')"
  [ "$OUTPUT}" == "UNKNOWN - deprecated argument provided: -t scalar" ]
}
