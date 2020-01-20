#!/bin/bash
#
# check_prometheus_metric.sh - Nagios plugin wrapper for checking Prometheus
#                              metrics. Requires curl and jq to be in $PATH.
source parse.bash

# Avoid locale complications:
export LC_ALL=C

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

# Regexes:
# TODO: Support negative numbers
INTEGER_REGEX="^[0-9]+$"
INTERVAL_REGEX="^[0-9]*(\.[0-9]+)?:[0-9]*(\.[0-9]+)?$"

# Variables:
NAGIOS_STATUS=UNKNOWN
NAGIOS_SHORT_TEXT='an unknown error occured'
NAGIOS_LONG_TEXT=''

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

function usage() {

  cat <<'EoL'

  check_prometheus_metric.sh - Nagios plugin wrapper for checking Prometheus
                               metrics. Requires curl and jq to be in $PATH.

  Usage:
  check_prometheus_metric.sh -H HOST -q QUERY -w FLOAT[:FLOAT] -c FLOAT[:FLOAT] -n NAME [-m METHOD] [-O] [-i] [-p] [-t QUERY_TYPE]

  Options:
    -H HOST          URL of Prometheus host to query.
    -q QUERY         Prometheus query, in single quotes, that returns by default a float or int (see -t).
    -w FLOAT[:FLOAT] Warning level value (must be a float or nagios-interval).
    -c FLOAT[:FLOAT] Critical level value (must be a float or nagios-interval).
    -n NAME          A name for the metric being checked.
    -m METHOD        Comparison method, one of gt, ge, lt, le, eq, ne.
                     (Defaults to ge unless otherwise specified.)
    -C CURL_OPTS     Additional flags to pass to curl.
                     Can be passed multiple times. Options and option values must be passed separately.
                     e.g. -C --conect-timetout -C 10 -C --cacert -C /path/to/ca.crt
    -O               Accept NaN as an "OK" result .
    -i               Print the extra metric information into the Nagios message.
    -p               Add perfdata to check output.

  Examples:
    check_prometheus_metric -q 'up{job=\"job_name\"}' :1 -c :1  # Check that job is up.
    
    check_prometheus_metric -q 'node_load1' -w :0.05 -c :0.1  # Check load is OK.
    # Aka. that load is below 0.05 and 0.1 respectively.

    check_prometheus_metric -q 'go_threads' -w 15:25 -c :  # Check thread count is OK.
    # Aka. OK if we have 15-25 threads, outside of this; warning, never critical.

EoL
}

function is_float_or_interval() {
    if is_float "${1}" || is_interval "${1}"; then
        return 0
    fi
    return 1
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
                NAGIOS_LONG_TEXT+="Note: The use of -t is deprecated, as the query-type is derived from the query."
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

  WARNING_RANGE=$(decode_range ${WARNING_LEVEL})
  WARNING_LEVEL_LOW=$(echo "${WARNING_RANGE}" | cut -f1 -d' ')
  WARNING_LEVEL_HIGH=$(echo "${WARNING_RANGE}" | cut -f2 -d' ')
  WARNING_INVERTED=$(echo "${WARNING_RANGE}" | cut -f3 -d' ')

  CRITICAL_RANGE=$(decode_range ${CRITICAL_LEVEL})
  CRITICAL_LEVEL_LOW=$(echo "${CRITICAL_RANGE}" | cut -f1 -d' ')
  CRITICAL_LEVEL_HIGH=$(echo "${CRITICAL_RANGE}" | cut -f2 -d' ')
  CRITICAL_INVERTED=$(echo "${CRITICAL_RANGE}" | cut -f3 -d' ')
 
  COMPARISON_OPERATOR="<="

  LEVEL_JSON="{\"critical_low\": ${CRITICAL_LEVEL_LOW}, \"critical_high\": ${CRITICAL_LEVEL_HIGH}, \"warning_low\": ${WARNING_LEVEL_LOW}, \"warning_high\": ${WARNING_LEVEL_HIGH}}"
  # Sanity check critical and warning levels
  if [ ${COMPARISON_METHOD} != "ne" ]; then
      echo "${LEVEL_JSON}" | jq -e ".critical_low ${COMPARISON_OPERATOR} .critical_high" >/dev/null
      CRITICAL_LEVEL_OK=$?
      echo "${LEVEL_JSON}" | jq -e ".warning_low ${COMPARISON_OPERATOR} .warning_high" >/dev/null
      WARNING_LEVEL_OK=$?
      if [ ${CRITICAL_LEVEL_OK} -ne 0 ]; then
        NAGIOS_STATUS=UNKNOWN
        NAGIOS_SHORT_TEXT="invalid critical range: ${CRITICAL_LEVEL_LOW} ${COMPARISON_OPERATOR} ${CRITICAL_LEVEL_HIGH}"
        exit
      fi
      if [ ${WARNING_LEVEL_OK} -ne 0 ]; then
        NAGIOS_STATUS=UNKNOWN
        NAGIOS_SHORT_TEXT="invalid warning range: ${WARNING_LEVEL_LOW} ${COMPARISON_OPERATOR} ${WARNING_LEVEL_HIGH}"
        exit
      fi
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
      echo "${JSON}" | jq -e ".critical_low ${COMPARISON_OPERATOR} .value and .value ${COMPARISON_OPERATOR} .critical_high" >/dev/null
      CRITICAL=$?
      echo "${JSON}" | jq -e ".warning_low ${COMPARISON_OPERATOR} .value and .value ${COMPARISON_OPERATOR} .warning_high" >/dev/null
      WARNING=$?
      # echo "${CRITICAL_LEVEL_LOW} ${COMPARISON_OPERATOR} ${PROMETHEUS_RESULT} ${COMPARISON_OPERATOR} ${CRITICAL_LEVEL_HIGH}" 1>&2
      # echo "${WARNING_LEVEL_LOW} ${COMPARISON_OPERATOR} ${PROMETHEUS_RESULT} ${COMPARISON_OPERATOR} ${WARNING_LEVEL_HIGH}" 1>&2

      if [ ${CRITICAL} -ne ${CRITICAL_INVERTED} ]; then
        NAGIOS_STATUS=CRITICAL
        NAGIOS_SHORT_TEXT="${METRIC_NAME} is ${PROMETHEUS_RESULT}"
      elif [ ${WARNING} -ne ${WARNING_INVERTED} ]; then
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
        PERF_DATA+="query_result=${PROMETHEUS_RESULT};${WARNING_LEVEL};${CRITICAL_LEVEL};U;U "

        NAGIOS_SHORT_TEXT="${NAGIOS_SHORT_TEXT} | ${PERF_DATA}"
    fi

    exit
fi
