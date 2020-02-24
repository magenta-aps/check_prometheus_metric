#!/bin/bash
# Find all source lines
SOURCE_LINES=$(grep "source .*" check_prometheus_metric.sh)

# Process the main script, by replacing source lines with their content
OUTPUT=$(cat check_prometheus_metric.sh)
while IFS= read -r LINE; do
    FILENAME=$(echo "${LINE}" | cut -f2 -d" ")
    OUTPUT=$(echo "${OUTPUT}" | sed -e "/source ${FILENAME}/{ r ${FILENAME}" -e "d}")
done <<< "${SOURCE_LINES}"

# Output the modified script
echo "${OUTPUT}"
