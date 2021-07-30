#!/bin/bash
#
# check_prometheus_metric.sh - Nagios plugin wrapper for checking Prometheus
#                              metrics. Requires curl and jq to be in $PATH.

# Default configuration:
CURL_OPTS=()
COMPARISON_METHOD=ge
NAN_OK="false"
NAGIOS_INFO="false"
PERFDATA="false"
PROMETHEUS_QUERY_TYPE=""

# Constants
#----------
# Nagios status codes:
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

# Variables:
NAGIOS_STATUS=UNKNOWN
NAGIOS_SHORT_TEXT='an unknown error occured'
NAGIOS_LONG_TEXT=''

# Includes
source preamble.bash
source parse.bash
source usage.bash

# Main

# Code:
function check_dependencies() {
    if ! [ -x "$(command -v curl)" ]; then
        NAGIOS_STATUS=UNKNOWN
        NAGIOS_SHORT_TEXT='missing "curl" command'
        exit
    fi

    if ! [ -x "$(command -v jq)" ]; then
        NAGIOS_STATUS=UNKNOWN
        NAGIOS_SHORT_TEXT='missing "jq" command'
    fi
}

function process_command_line {

  while getopts ':H:q:w:c:m:n:C:Oipt:' OPT "$@"
  do
    case ${OPT} in
      H)        PROMETHEUS_SERVER="$OPTARG" ;;
      q)        PROMETHEUS_QUERY="$OPTARG" ;;
      n)        METRIC_NAME="$OPTARG" ;;

      m)        # If invalid operator name
                if ! [[ ${OPTARG} =~ ^([lg][et]|eq|ne)$ ]]; then
                    NAGIOS_SHORT_TEXT="invalid comparison method: ${OPTARG}"
                    NAGIOS_LONG_TEXT="$(usage)"
                    exit
                fi
                COMPARISON_METHOD=${OPTARG}
                ;;

      c)        # If malformed
                if ! is_float_or_interval "${OPTARG}"; then
                  NAGIOS_SHORT_TEXT='-c CRITICAL_LEVEL requires a float or interval'
                  NAGIOS_LONG_TEXT="$(usage)"
                  exit
                fi
                CRITICAL_LEVEL=${OPTARG}
                ;;

      w)        # If malformed
                if ! is_float_or_interval "${OPTARG}"; then
                  NAGIOS_SHORT_TEXT='-w WARNING_LEVEL requires a float or interval'
                  NAGIOS_LONG_TEXT="$(usage)"
                  exit
                fi
                WARNING_LEVEL=${OPTARG}
                ;;

      C)        CURL_OPTS+=("${OPTARG}")
                ;;
      O)        NAN_OK="true"
                ;;

      i)        NAGIOS_INFO="true"
                ;;

      p)        PERFDATA="true"
                ;;

      t)
                NAGIOS_LONG_TEXT+="Note: The use of -t is deprecated, as the query-type is derived from the query result."
                ;;

      \?)       NAGIOS_SHORT_TEXT="invalid option: -$OPTARG"
                NAGIOS_LONG_TEXT="$(usage)"
                exit
                ;;

      \:)       NAGIOS_SHORT_TEXT="-$OPTARG requires an arguement"
                NAGIOS_LONG_TEXT="$(usage)"
                exit
                ;;
    esac
  done

  # check for missing parameters
  if [[ -z ${PROMETHEUS_SERVER} ]] ||
     [[ -z ${PROMETHEUS_QUERY} ]] ||
     [[ -z ${METRIC_NAME} ]] ||
     [[ -z ${WARNING_LEVEL} ]] ||
     [[ -z ${CRITICAL_LEVEL} ]]
  then
    NAGIOS_SHORT_TEXT='missing required option'
    NAGIOS_LONG_TEXT+="$(usage)"
    exit
  fi
  # Convert old syntax to new syntax
  # Warning
  if is_float "${WARNING_LEVEL}"; then
      if [[ "${COMPARISON_METHOD}" == "ge" ]]; then
          WARNING_LEVEL="0:$(echo ${WARNING_LEVEL} | jq '. - 1e-9')"
      elif [[ "${COMPARISON_METHOD}" == "eq" ]]; then
          WARNING_LEVEL="@${WARNING_LEVEL}:${WARNING_LEVEL}"
      elif [[ "${COMPARISON_METHOD}" == "ne" ]]; then
          WARNING_LEVEL="${WARNING_LEVEL}:${WARNING_LEVEL}"
      elif [[ "${COMPARISON_METHOD}" == "lt" ]]; then
          WARNING_LEVEL="${WARNING_LEVEL}:"
      elif [[ "${COMPARISON_METHOD}" == "le" ]]; then
          WARNING_LEVEL="$(echo ${WARNING_LEVEL} | jq '. + 1e-9'):"
      fi
  fi
  # Critical
  if is_float "${CRITICAL_LEVEL}"; then
      if [[ "${COMPARISON_METHOD}" == "ge" ]]; then
          CRITICAL_LEVEL="0:$(echo ${CRITICAL_LEVEL} | jq '. - 1e-9')"
      elif [[ "${COMPARISON_METHOD}" == "eq" ]]; then
          CRITICAL_LEVEL="@${CRITICAL_LEVEL}:${CRITICAL_LEVEL}"
      elif [[ "${COMPARISON_METHOD}" == "ne" ]]; then
          CRITICAL_LEVEL="${CRITICAL_LEVEL}:${CRITICAL_LEVEL}"
      elif [[ "${COMPARISON_METHOD}" == "lt" ]]; then
          CRITICAL_LEVEL="${CRITICAL_LEVEL}:"
      elif [[ "${COMPARISON_METHOD}" == "le" ]]; then
          CRITICAL_LEVEL="$(echo ${CRITICAL_LEVEL} | jq '. + 1e-9'):"
      fi
  fi
  # Decode new syntax
  # Warning
  WARNING_RANGE=$(decode_range ${WARNING_LEVEL})
  WARNING_LEVEL_LOW=$(echo "${WARNING_RANGE}" | cut -f1 -d' ')
  WARNING_LEVEL_HIGH=$(echo "${WARNING_RANGE}" | cut -f2 -d' ')
  WARNING_INVERTED=$(echo "${WARNING_RANGE}" | cut -f3 -d' ')
  # Critical
  CRITICAL_RANGE=$(decode_range ${CRITICAL_LEVEL})
  CRITICAL_LEVEL_LOW=$(echo "${CRITICAL_RANGE}" | cut -f1 -d' ')
  CRITICAL_LEVEL_HIGH=$(echo "${CRITICAL_RANGE}" | cut -f2 -d' ')
  CRITICAL_INVERTED=$(echo "${CRITICAL_RANGE}" | cut -f3 -d' ')
  # Bake our levels json
  LEVEL_JSON="{\"critical_low\": ${CRITICAL_LEVEL_LOW}, \"critical_high\": ${CRITICAL_LEVEL_HIGH}, \"warning_low\": ${WARNING_LEVEL_LOW}, \"warning_high\": ${WARNING_LEVEL_HIGH}}"
  # Sanity check critical and warning levels
  if [ ${COMPARISON_METHOD} != "ne" ]; then
      echo "${LEVEL_JSON}" | jq -e ".critical_low <= .critical_high" >/dev/null
      CRITICAL_LEVEL_OK=$?
      echo "${LEVEL_JSON}" | jq -e ".warning_low <= .warning_high" >/dev/null
      WARNING_LEVEL_OK=$?
      if [ ${CRITICAL_LEVEL_OK} -ne 0 ]; then
        NAGIOS_STATUS=UNKNOWN
        NAGIOS_SHORT_TEXT="invalid critical range: ${CRITICAL_LEVEL_LOW} <= ${CRITICAL_LEVEL_HIGH}"
        exit
      fi
      if [ ${WARNING_LEVEL_OK} -ne 0 ]; then
        NAGIOS_STATUS=UNKNOWN
        NAGIOS_SHORT_TEXT="invalid warning range: ${WARNING_LEVEL_LOW} <= ${WARNING_LEVEL_HIGH}"
        exit
      fi
  fi
}


function check_prometheus_server {
    # Check that the server URL responds
    curl "${CURL_OPTS[@]}" --silent --head ${PROMETHEUS_SERVER}/api/v1/query > /dev/null
    SERVER_RESPONDED=$?
    if [ "${SERVER_RESPONDED}" -ne 0 ]; then
        NAGIOS_STATUS=UNKNOWN
        NAGIOS_SHORT_TEXT="no response from prometheus"
        exit
    fi

    # Check if the prometheus endpoint exists, and can be queried
    curl -s "${CURL_OPTS[@]}" ${PROMETHEUS_SERVER}/api/v1/query?query=cafebabe | jq -e '.status == "success"' 1>/dev/null 2>/dev/null
    PROMETHEUS_OK=$?
    if [ "${PROMETHEUS_OK}" -ne 0 ]; then
        NAGIOS_STATUS=UNKNOWN
        NAGIOS_SHORT_TEXT="unable to query prometheus endpoint!"
        exit
    fi
}


function get_prometheus_raw_result {

  local _RESULT

  _RESULT=$(curl -sgG "${CURL_OPTS[@]}" --data-urlencode "query=${PROMETHEUS_QUERY}" "${PROMETHEUS_SERVER}/api/v1/query")
  printf '%s' "${_RESULT}"

}

function get_prometheus_scalar_result {

  local _RESULT

  _RESULT=$(echo $1 | jq -r '.[1]')

  # check result
  case "${_RESULT}" in
    +Inf) printf '%s' 'inf'
          ;;
    -Inf) printf '%s' '-inf'
          ;;
    *)    printf '%s' "${_RESULT}" # otherwise return as a string
          ;;
  esac
}

function get_prometheus_vector_value {

  local _RESULT

  # return the value of the first element of the vector
  _RESULT=$(echo $1 | jq -r '.[0].value?')
  printf '%s' "${_RESULT}"

}

function get_prometheus_vector_metric {

  local _RESULT

  # return the metric information of the first element of the vector
  _RESULT=$(echo $1 | jq -r '.[0].metric?' | xargs)
  printf '%s' "${_RESULT}"

}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Exit trigger
    #-------------
    # Function to be trapped on exit
    function on_exit {
        if [[ -n ${NAGIOS_LONG_TEXT} ]]; then
            printf '%s\n' "${NAGIOS_LONG_TEXT}"
        fi
        printf '%s - %s\n' ${NAGIOS_STATUS} "${NAGIOS_SHORT_TEXT}"
        # Indirect variable reference
        exit ${!NAGIOS_STATUS}
    }

    # Set up exit function
    trap on_exit EXIT TERM

    check_dependencies
    # process the cli options
    process_command_line "$@"

    # Check that we can communicate with the prometheus server
    check_prometheus_server

    # get the raw query from prometheus
    PROMETHEUS_RAW_RESPONSE="$( get_prometheus_raw_result )"

    PROMETHEUS_QUERY_TYPE=$(echo "${PROMETHEUS_RAW_RESPONSE}" | jq -r '.data.resultType')
    PROMETHEUS_RAW_RESULT=$(echo "${PROMETHEUS_RAW_RESPONSE}" | jq -r '.data.result')

    # extract the metric value from the raw prometheus result
    if [[ "${PROMETHEUS_QUERY_TYPE}" == "scalar" ]]; then
        PROMETHEUS_RESULT=$( get_prometheus_scalar_result "$PROMETHEUS_RAW_RESULT" )
        PROMETHEUS_METRIC=UNKNOWN
    else
        PROMETHEUS_VALUE=$( get_prometheus_vector_value "$PROMETHEUS_RAW_RESULT" )
        PROMETHEUS_RESULT=$( get_prometheus_scalar_result "$PROMETHEUS_VALUE" )
        PROMETHEUS_METRIC=$( get_prometheus_vector_metric "$PROMETHEUS_RAW_RESULT" )
    fi

    # check the value
    if is_float ${PROMETHEUS_RESULT}; then
      JSON=$(echo "${LEVEL_JSON} {\"value\": ${PROMETHEUS_RESULT}}" | jq -s add)
      # Evaluate critical and warning levels
      echo "${JSON}" | jq -e ".critical_low <= .value and .value <= .critical_high" >/dev/null
      IS_CRITICAL=$?
      echo "${JSON}" | jq -e ".warning_low <= .value and .value <= .warning_high" >/dev/null
      IS_WARNING=$?

      if [ ${IS_CRITICAL} -ne ${CRITICAL_INVERTED} ]; then
        NAGIOS_STATUS=CRITICAL
        NAGIOS_SHORT_TEXT="${METRIC_NAME} is ${PROMETHEUS_RESULT}"
      elif [ ${IS_WARNING} -ne ${WARNING_INVERTED} ]; then
        NAGIOS_STATUS=WARNING
        NAGIOS_SHORT_TEXT="${METRIC_NAME} is ${PROMETHEUS_RESULT}"
      else
        NAGIOS_STATUS=OK
        NAGIOS_SHORT_TEXT="${METRIC_NAME} is ${PROMETHEUS_RESULT}"
      fi
    else
      if [[ "${NAN_OK}" = "true" && "${PROMETHEUS_RESULT}" = "NaN" ]]; then
        NAGIOS_STATUS=OK
        NAGIOS_SHORT_TEXT="${METRIC_NAME} is ${PROMETHEUS_RESULT}"
      else
        NAGIOS_SHORT_TEXT="unable to parse prometheus response"
        NAGIOS_LONG_TEXT="${METRIC_NAME} is ${PROMETHEUS_RESULT}"
      fi
    fi
    if [[ "${NAGIOS_INFO}" = "true" ]]; then
        NAGIOS_SHORT_TEXT="${NAGIOS_SHORT_TEXT}: ${PROMETHEUS_METRIC}"
    fi
    if [[ "${PERFDATA}" = "true" ]]; then
        # Bake performance data
        PERF_DATA=""
        PERF_DATA+="query_result=${PROMETHEUS_RESULT};${WARNING_LEVEL};${CRITICAL_LEVEL};U;U"
        # PERF_DATA+=" "

        NAGIOS_SHORT_TEXT="${NAGIOS_SHORT_TEXT} | ${PERF_DATA}"
    fi

    exit
fi
