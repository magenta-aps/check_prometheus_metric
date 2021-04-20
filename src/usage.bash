function usage() {

  cat <<'EoL'

  check_prometheus_metric.sh - Nagios plugin for checking Prometheus metrics.

  Usage:
    check_prometheus_metric.sh -H HOST -q QUERY -w FLOAT[:FLOAT] -c FLOAT[:FLOAT]
                               -n NAME [-m METHOD] [-O] [-i] [-p]

  Options:
    -H HOST          URL of Prometheus host to query.
    -q QUERY         Prometheus query, in single quotes, that returns a float.
    -w FLOAT[:FLOAT] Warning level value (must be a float or nagios-interval).
    -c FLOAT[:FLOAT] Critical level value (must be a float or nagios-interval).
    -n NAME          A name for the metric being checked.
    -m METHOD        Comparison method, one of gt, ge, lt, le, eq, ne.
                     (Defaults to ge unless otherwise specified).
    -C CURL_OPTS     Additional flags to curl. Can be passed multiple times.
                     Options and option values must be passed separately.
                     e.g. -C --connect-timeout -C 10 -C --cacert -C /path/to/ca.crt
    -O               Accept NaN as an "OK" result.
    -0               Accept null as an "OK" result.
    -i               Print the extra metric information into the Nagios message.
    -p               Add perfdata to check output.

  Examples:
    check_prometheus_metric -q 'up{job=\"job_name\"}' -w :1 -c :1
    # Check that job is up. If not, critical.

    check_prometheus_metric -q 'node_load1' -w :0.05 -c :0.1
    # Check load is below 0.05 (warning) and 0.1 (critical).

    check_prometheus_metric -q 'go_threads' -w 15:25 -c :
    # Check thread count is between 15-25, warning if outside this interval.

  Dependencies:
    Requires bash, curl, cut, echo, grep, jq and sed to be in $PATH.

EoL
}
