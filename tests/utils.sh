function wait_for_metric() {
    PARSED_RESULT="NaN"
    # Keep running query until data is found, i.e. non-nan returned
    until [ "${PARSED_RESULT}" != "NaN" ]; do
        printf '.'
        sleep 1
        RAW_RESULT=$(curl -s --data-urlencode "query=$1" "http://localhost:$2/api/v1/query")
        PARSED_RESULT=$(echo "${RAW_RESULT}" | jq -r .data.result[1])
    done
}

TOTAL_TESTS=0
TOTAL_FAILS=0
function check() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if [ "$1" != "$2" ]; then
        TOTAL_FAILS=$((TOTAL_FAILS + 1))
        printf "x"
        # printf "\n$1 != $2\n"
    else
        printf "."
    fi
}

function parameterized_tests() {
    # Loop through each test-case
    while IFS= read -r line; do
        PARAMETERS=$(echo "$line" | cut -f1 -d'#')
        EXPECTED=$(echo "$line" | cut -f2 -d'#')
        RESULT=$(bash ${PLUGIN_SCRIPT} -H "${PROMETHEUS_SERVER}" ${PARAMETERS} -n "tc" | head -1)
        check "$RESULT" "$EXPECTED"
    done <<< "$1"
}
