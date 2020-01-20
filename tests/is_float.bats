#!/usr/bin/env bats

load parse

# Test is_float
#--------------
# Ordinary floats
@test "Test float regex: 10" {
  is_float "10"
}
@test "Test float regex: 10.5" {
  is_float "10.5"
}
@test "Test float regex: 3.14" {
  is_float "3.14"
}
@test "Test float regex: 42.42" {
  is_float "42.42"
}
@test "Test float regex: .11" {
  is_float ".11"
}

# Prefix +
@test "Test float regex: +10" {
  is_float "+10"
}
@test "Test float regex: +10.5" {
  is_float "+10.5"
}
@test "Test float regex: +3.14" {
  is_float "+3.14"
}
@test "Test float regex: +42.42" {
  is_float "+42.42"
}
@test "Test float regex: +.11" {
  is_float "+.11"
}

# Prefix -
@test "Test float regex: -10" {
  is_float "-10"
}
@test "Test float regex: -10.5" {
  is_float "-10.5"
}
@test "Test float regex: -3.14" {
  is_float "-3.14"
}
@test "Test float regex: -42.42" {
  is_float "-42.42"
}
@test "Test float regex: -.11" {
  is_float "-.11"
}

# Test bad-floats
@test "Test bad float regex: 10." {
  ! is_float "10."
}
@test "Test bad float regex: one" {
  ! is_float "one"
}
@test "Test bad float regex: .+11" {
  ! is_float ".+11"
}
