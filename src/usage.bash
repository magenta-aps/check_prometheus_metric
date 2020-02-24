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
