#!/usr/bin/env bats

load ../src/parse

@test "--- ${BATS_TEST_FILENAME} ---" {
  true
}
# Test is_interval
#-----------------
# Ordinary intervals
@test "Test interval regex: 10:" {
  is_interval "10:"
}
@test "Test interval regex: ~:10" {
  is_interval "~:20"
}
@test "Test interval regex: 10:20" {
  is_interval "10:20"
}
