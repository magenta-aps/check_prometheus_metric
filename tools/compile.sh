#!/bin/bash
cd src
MAIN=check_prometheus_metric.sh

# Find all source lines
SOURCE_LINES=$(grep "source .*" ${MAIN})

# Process the main script, by replacing source lines with their content
OUTPUT=$(cat ${MAIN})
while IFS= read -r LINE; do
    FILENAME=$(echo "${LINE}" | cut -f2 -d" ")
    OUTPUT=$(echo "${OUTPUT}" | sed -e "s/source ${FILENAME}/\n# Included: ${FILENAME}\nsource ${FILENAME}/g")
    OUTPUT=$(echo "${OUTPUT}" | sed -e "/source ${FILENAME}/{ r ${FILENAME}" -e "d}")
done <<< "${SOURCE_LINES}"

# Output the modified script
echo "${OUTPUT}"
