#!/bin/bash

FLOAT_REGEX="[+-]?([0-9]*[.])?[0-9]+"
INTERVAL_REGEX="([~]|${FLOAT_REGEX}):(${FLOAT_REGEX})?"

function is_inverted {
    # Inverted if string starts with @
    local _IS_INVERTED
    echo "${1}" | grep -E "^@" -c >/dev/null
    _IS_INVERTED=$?
    return ${_IS_INVERTED}
}

function is_float() {
    local _IS_FLOAT
    echo "${1}" | grep -E "^${FLOAT_REGEX}$" -c >/dev/null
    _IS_FLOAT=$?
    return ${_IS_FLOAT}
}

function is_interval() {
    local _IS_INTERVAL=0
    echo "${1}" | grep -E "^${INTERVAL_REGEX}$" -c >/dev/null
    _IS_INTERVAL=$?
    return ${_IS_INTERVAL}
}

function decode_range() {
    # Decode Nagios Threshold format string.
    #
    # For reference, see: https://nagios-plugins.org/doc/guidelines.html#THRESHOLDFORMAT
    #
    # Examples:
    #   Input: "10:20", Output: "10 20"
    #   Input: "@~:3.14", Output: "-inf 3.14 inverted"
    # Input variable
    local _INPUT=$1
    # Output variables
    local _START="0"
    local _END="inf"
    local _INVERTED="0"
    # Check if inverted
    if is_inverted "${_INPUT}"; then
        _INVERTED="1"
        # Remove @ from string
        _INPUT="${_INPUT:1}"
    fi
    # Check if lonely float (i.e. implicit interval)
    if is_float "${_INPUT}"; then
        _END=${_INPUT}
    # Check if valid interval
    elif is_interval "${_INPUT}"; then
        # Fetch parts of interval seperately
        _START=$(echo "${_INPUT}" | cut -f1 -d':')
        _END=$(echo "${_INPUT}" | cut -f2 -d':')
        # Replace ~ in start with -inf
        _START=$(echo "${_START}" | sed "s/^~$/-inf/g")
        # Replace empty in end with inf
        _END=$(echo "${_END}" | sed "s/^$/inf/g")
    else  # Not valid float or interval
        echo "Unable to parse range"
        return 1
    fi
    # Strip prefix +
    _START=$(echo ${_START} | cut -f2 -d'+')
    _END=$(echo ${_END} | cut -f2 -d'+')
    # Output space-seperated string
    printf '%s' "${_START} ${_END} ${_INVERTED}"
    return 0
}
