<img align="right" src="https://user-images.githubusercontent.com/225151/75162092-3ef2f780-571d-11ea-8d4e-616ccbd1c924.png" width="200" height="200"/>

`check_prometheus_metric`
=========================
![CI](https://github.com/magenta-aps/check_prometheus_metric/workflows/CI/badge.svg)

Nagios plugin for alerting on Prometheus query results.

# Usage
```
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
    -E               Accept an empty vector (null) as an "OK" result.
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
```
Note: `nagios-interval` refers to [this syntax](http://nagios-plugins.org/doc/guidelines.html#THRESHOLDFORMAT)

# Icinga configuration
To utilize the script with [Icinga 2](https://icinga.com/docs/icinga2/), four
steps must be taken;

1. The CheckCommand definition must be added to `/etc/icinga2/conf.d/check_prometheus_metric.conf`:
```
object CheckCommand "check_prometheus_metric" {
  import "plugin-check-command"
  command = [ "/usr/lib/nagios/plugins/check_prometheus_metric" ]

  arguments = {
        "-H" = {
                value = "$check_prometheus_metric_url$"
                description = "URL of Prometheus host to query."
        }
        "-q" = {
                value = "$check_prometheus_metric_query$"
                description = "Prometheus query, that returns a float."
        }
        "-w" = {
                value = "$check_prometheus_metric_warning$"
                description = "Warning level value (float or nagios-interval)."
        }
        "-c" = {
                value = "$check_prometheus_metric_critical$"
                description = "Critical level value (float or nagios-interval)."
        }
        "-n" = {
                value = "$check_prometheus_metric_name$"
                description = "A name for the metric being checked."
        }
    }
}
```
2. The checking script, must be added to `/usr/lib/nagios/plugins/check_prometheus_metric`:
```
GIT_REPO=https://github.com/magenta-aps/check_prometheus_metric
VERSION=$(curl -sL -H "Accept: application/json" ${GIT_REPO}/releases/latest | jq -r .tag_name)
curl -sL -o . ${GIT_REPO}/releases/download/${VERSION}/check_prometheus_metric.sh
chmod +x check_prometheus_metric.sh
sudo mv check_prometheus_metric.sh /usr/lib/nagios/plugins/check_prometheus_metric
```

3. Install the required software to run the script:
```
sudo apt-get update
sudo apt-get install -y bash coreutils curl grep jq sed
```

4. Add Service definitions for whatever is to be monitored:

`/etc/icinga2/conf.d/check_pi_service.conf`:
```
apply Service "pi" {
  import "generic-service"

  check_command = "check_prometheus_metric"

  vars.check_prometheus_metric_url = "prometheus:9090"
  vars.check_prometheus_metric_query = "pi"
  vars.check_prometheus_metric_warning = "3:4"
  vars.check_prometheus_metric_critical = "1:6"
  vars.check_prometheus_metric_name = "pi"
  
  command_endpoint = host.vars.client_endpoint
  assign where host.name == NodeName
}
```

# Nagios configuration
You need to add the following commands to your Nagios configuration to use it:
```
define command {
    command_name check_prometheus
    command_line $USER1$/check_prometheus_metric.sh -H '$ARG1$' -q '$ARG2$' -w '$ARG3$' -c '$ARG4$' -n '$ARG5$' -m '$ARG6$'
}
```
