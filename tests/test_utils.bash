function test_parameters() {
    local _PARAMETERS
    local _OUTPUT
    _PARAMETERS=$1
    _OUTPUT=$(bash ${PLUGIN_SCRIPT} -H "${PROMETHEUS_SERVER}" ${_PARAMETERS} -n "tc" | head -1)
    printf '%s' "${_OUTPUT}"
    return 0
}
