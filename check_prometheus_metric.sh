#!/bin/bash
#
# check_prometheus_metric.sh - Nagios plugin wrapper for checking Prometheus
#                              metrics. Requires curl and jq to be in $PATH.

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
  check_prometheus_metric.sh -H HOST -q QUERY -w INT[:INT] -c INT[:INT] -n NAME [-m METHOD] [-O] [-i] [-p] [-t QUERY_TYPE]

  options:
    -H HOST          URL of Prometheus host to query.
    -q QUERY         Prometheus query, in single quotes, that returns by default a float or int (see -t).
    -w INT[:INT]     Warning level value (must be zero or positive).
    -c INT[:INT]     Critical level value (must be zero or positive).
    -n NAME          A name for the metric being checked.
    -m METHOD        Comparison method, one of gt, ge, lt, le, eq, ne.
                     (Defaults to ge unless otherwise specified.)
    -C CURL_OPTS     Additional flags to pass to curl.
                     Can be passed multiple times. Options and option values must be passed separately.
                     e.g. -C --conect-timetout -C 10 -C --cacert -C /path/to/ca.crt
    -O               Accept NaN as an "OK" result .
    -i               Print the extra metric information into the Nagios message.
    -p               Add perfdata to check output.

EoL
}

function is_integer() {
    echo "${1}" | grep -E "${INTEGER_REGEX}" -c >/dev/null
    IS_INTEGER=$?
    return ${IS_INTEGER}
}

function is_interval() {
    echo "${1}" | grep -E "${INTERVAL_REGEX}" -c >/dev/null
    IS_INTERVAL=$?
    return ${IS_INTERVAL}
}

function is_integer_or_interval() {
    if is_integer "${1}" || is_interval "${1}"; then
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
                if ! is_integer_or_interval "${OPTARG}"; then
                  NAGIOS_SHORT_TEXT='-c CRITICAL_LEVEL requires an integer or interval'
                  NAGIOS_LONG_TEXT="$(usage)"
                  exit
                fi
                CRITICAL_LEVEL=${OPTARG}
                ;;

      w)        # If malformed
                if ! is_integer_or_interval "${OPTARG}"; then
                  NAGIOS_SHORT_TEXT='-w WARNING_LEVEL requires an integer or interval'
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
                NAGIOS_SHORT_TEXT="deprecated argument provided: ${OPTARG}"
                NAGIOS_LONG_TEXT="$(usage)"
                exit
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
    NAGIOS_LONG_TEXT="$(usage)"
    exit
  fi

  # List of valid operators
  COMPARISON_OPERATORS='{"gt": ">", "ge": ">=", "lt": "<", "le": "<=", "eq": "==", "ne": "!="}'
  # jq query to pick out the selected operator
  COMPARISON_OPERATOR=$(echo "${COMPARISON_OPERATORS}" | jq -r ".${COMPARISON_METHOD}")
  # If operator was not found
  if [ ${COMPARISON_OPERATOR} == 'null' ]; then
      NAGIOS_SHORT_TEXT="Unable to find comparison method: ${OPTARG}"
      NAGIOS_LONG_TEXT="$(usage)"
      exit
  fi

  # Derive intervals
  CRITICAL_LEVEL_LOW=$(echo ${CRITICAL_LEVEL} | cut -f1 -d':')
  CRITICAL_LEVEL_HIGH=$(echo ${CRITICAL_LEVEL} | cut -f2 -d':')
  WARNING_LEVEL_LOW=$(echo ${WARNING_LEVEL} | cut -f1 -d':')
  WARNING_LEVEL_HIGH=$(echo ${WARNING_LEVEL} | cut -f2 -d':')
  CRITICAL_LEVEL_LOW=${CRITICAL_LEVEL_LOW:='-inf'}
  CRITICAL_LEVEL_HIGH=${CRITICAL_LEVEL_HIGH:='inf'}
  WARNING_LEVEL_LOW=${WARNING_LEVEL_LOW:='-inf'}
  WARNING_LEVEL_HIGH=${WARNING_LEVEL_HIGH:='inf'}
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
  if [[ ${_RESULT} =~ ^-?[0-9]+\.?[0-9]*$ ]]
  then
    printf '%.0F' ${_RESULT} # return an int if result is a number
  else
    case "${_RESULT}" in
      +Inf) printf '%.0F' $(( ${WARNING_LEVEL} + ${CRITICAL_LEVEL} )) # something greater than either level
            ;;
      -Inf) printf -- '-1' # something smaller than any level
            ;;
      *)    printf '%s' "${_RESULT}" # otherwise return as a string
            ;;
    esac
  fi
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
        printf '%s - %s\n' ${NAGIOS_STATUS} "${NAGIOS_SHORT_TEXT}"

        if [[ -n ${NAGIOS_LONG_TEXT} ]]; then
            printf '%s\n' "${NAGIOS_LONG_TEXT}"
        fi
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
    if [[ "${PROMETHEUS_QUERY_TYPE}" = "scalar" ]]; then
        PROMETHEUS_RESULT=$( get_prometheus_scalar_result "$PROMETHEUS_RAW_RESULT" )
        PROMETHEUS_METRIC=UNKNOWN
    else
        PROMETHEUS_VALUE=$( get_prometheus_vector_value "$PROMETHEUS_RAW_RESULT" )
        PROMETHEUS_RESULT=$( get_prometheus_scalar_result "$PROMETHEUS_VALUE" )
        PROMETHEUS_METRIC=$( get_prometheus_vector_metric "$PROMETHEUS_RAW_RESULT" ) 
    fi

    # check the value
    if [[ ${PROMETHEUS_RESULT} =~ ^-?[0-9]+$ ]]; then
      # JSON raw data
      JSON="{\"value\": ${PROMETHEUS_RESULT}, \"critical\": ${CRITICAL_LEVEL}, \"warning\": ${WARNING_LEVEL}}"
      # Evaluate critical and warning levels
      echo "${JSON}" | jq -e ".value ${COMPARISON_OPERATOR} .critical" >/dev/null
      CRITICAL=$?
      echo "${JSON}" | jq -e ".value ${COMPARISON_OPERATOR} .warning" >/dev/null
      WARNING=$?

      if [ ${CRITICAL} -eq 0 ]; then
        NAGIOS_STATUS=CRITICAL
        NAGIOS_SHORT_TEXT="${METRIC_NAME} is ${PROMETHEUS_RESULT}"
      elif [ ${WARNING} -eq 0 ]; then
        NAGIOS_STATUS=WARNING
        NAGIOS_SHORT_TEXT="${METRIC_NAME} is ${PROMETHEUS_RESULT}"
      else
        NAGIOS_STATUS=OK
        NAGIOS_SHORT_TEXT="${METRIC_NAME} is ${PROMETHEUS_RESULT}"
      fi
    else
      if [[ "${NAN_OK}" = "true" && "${PROMETHEUS_RESULT}" = "NaN" ]]
      then
        NAGIOS_STATUS=OK
        NAGIOS_SHORT_TEXT="${METRIC_NAME} is ${PROMETHEUS_RESULT}"
      else    
        NAGIOS_SHORT_TEXT="unable to parse prometheus response"
        NAGIOS_LONG_TEXT="${METRIC_NAME} is ${PROMETHEUS_RESULT}"
      fi
    fi
    if [[ "${NAGIOS_INFO}" = "true" ]]
    then
        NAGIOS_SHORT_TEXT="${NAGIOS_SHORT_TEXT}: ${PROMETHEUS_METRIC}"
    fi
    if [[ "${PERFDATA}" = "true" ]]
    then
        NAGIOS_SHORT_TEXT="${NAGIOS_SHORT_TEXT} | query_result=${PROMETHEUS_RESULT}"
    fi

    exit
fi
