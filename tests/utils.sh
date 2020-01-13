TOTAL_TESTS=0
TOTAL_FAILS=0
function check() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if [ "$1" != "$2" ]; then
        TOTAL_FAILS=$((TOTAL_FAILS + 1))
        printf "x"
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
