#!/usr/bin/env bats

load ../parse

@test "--- ${BATS_TEST_FILENAME} ---" {
  true
}
# Test decode_range
#------------------
@test "Test valid range: ''" {
  RANGE="$(! decode_range '' 2>&1)"
  [ "${RANGE}" == "Unable to parse range" ]
}
@test "Test valid range: 10" {
  RANGE="$(decode_range '10')"
  [ "${RANGE}" == "0 10 0" ]
}
@test "Test valid range: @10" {
  RANGE="$(decode_range '@10')"
  [ "${RANGE}" == "0 10 1" ]
}
@test "Test valid range: +3.14" {
  RANGE="$(decode_range '+3.14')"
  [ "${RANGE}" == "0 3.14 0" ]
}
@test "Test valid range: 10:" {
  RANGE="$(decode_range '10:')"
  [ "${RANGE}" == "10 inf 0" ]
}
@test "Test valid range: @10:" {
  RANGE="$(decode_range '@10:')"
  [ "${RANGE}" == "10 inf 1" ]
}
@test "Test valid range: +3.14:" {
  RANGE="$(decode_range '+3.14:')"
  [ "${RANGE}" == "3.14 inf 0" ]
}
@test "Test valid range: ~:10" {
  RANGE="$(decode_range '~:10')"
  [ "${RANGE}" == "-inf 10 0" ]
}
@test "Test valid range: ~:+3.14" {
  RANGE="$(decode_range '~:+3.14')"
  [ "${RANGE}" == "-inf 3.14 0" ]
}
@test "Test valid range: 10:20" {
  RANGE="$(decode_range '10:20')"
  [ "${RANGE}" == "10 20 0" ]
}
@test "Test valid range: +3.14:+42" {
  RANGE="$(decode_range '+3.14:+42')"
  [ "${RANGE}" == "3.14 42 0" ]
}
@test "Test valid range: @10:20" {
  RANGE="$(decode_range '@10:20')"
  [ "${RANGE}" == "10 20 1" ]
}
@test "Test valid range: @+3.14:+42" {
  RANGE="$(decode_range '@+3.14:+42')"
  [ "${RANGE}" == "3.14 42 1" ]
}
@test "Test valid range: @-3.14:+42.11" {
  RANGE="$(decode_range '@-3.14:+42')"
  [ "${RANGE}" == "-3.14 42 1" ]
}
@test "Test valid range: @~:+3.14" {
  RANGE="$(decode_range '@~:+3.14')"
  [ "${RANGE}" == "-inf 3.14 1" ]
}
