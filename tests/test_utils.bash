function test_parameters() {
    local _PARAMETERS
    local _OUTPUT
    _PARAMETERS=$1
    _OUTPUT=$(bash ${PLUGIN_SCRIPT} -H "${PROMETHEUS_SERVER}" ${_PARAMETERS} -n "tc" | tail -1)
    printf '%s' "${_OUTPUT}"
    return 0
}

function wait_for_metric() {
    local _RAW_RESULT
    local _PARSED_RESULT="NaN"
    # Keep running query until data is found, i.e. non-nan returned
    until [ "${PARSED_RESULT}" != "NaN" ]; do
        printf '.'
        sleep 1
        _RAW_RESULT=$(curl -s --data-urlencode "query=$1" "http://localhost:$2/api/v1/query")
        _PARSED_RESULT=$(echo "${RAW_RESULT}" | jq -r .data.result[1])
    done
    return 0
}
