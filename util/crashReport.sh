#!/bin/bash

# TODO
# Collect JSON logging data
# Add (and modify) Docker container, use -XX:OnError , -XX:OnOutOfMemoryError and -XX:ErrorFile
# remove 'logging' echo statements
# replace all hard-coded data with variabled from Docker container
# configure logging in Docker container to be picked up
# Any other script improvements?

# Variables for script usage
FILE_HS_ERR_LOG=hs_err.log
FILE_AGENT_LOG_1=
FILE_AGENT_LOG_2=

# Variables for use in the JSON payload
JSON_HOSTNAME="$(hostname)"
JSON_TIMESTAMP="$(date +%s)000"
JSON_PID="${1}"
if [ "${2}" != "" ]; then
  JSON_ERROR="${2}"
else
  JSON_ERROR="Unknown reason for Agent crash"
fi


post_crash_data() {
  echo
  echo $(generate_crash_data)
  echo
  # Silence all output so it doesn't show up in e.g. Docker or Kubernetes logs
  curl -XPOST https://test-instana.instana.io:444/metrics \
    --silent \
	--http2-prior-knowledge \
	--header "x-instana-key: FY5ncq4NTfi6-lmYPBjraA" \
	--header "x-instana-host: ${JSON_HOSTNAME}" \
	--header "Content-Type: application/json" \
	--data "$(generate_crash_data)" \
    --output /dev/null 2>&1
  }

#
# Generates the JSON data for sending the crash report. Expects the following variables set:
# - JSON_HOSTNAME: the hostname where the agent runs
# - JSON_TIMESTAMP: timestamp when crash occurred
# - JSON_PID: PID of the crashed Agent
# - JSON_ERROR: the description of the error
# - JSON_LOGS: Last log-lines captured from the agent
#
generate_crash_data() {
  cat <<-EOF
{
  "plugins": [
	{
	  "name": "com.instana.agent",
	  "hostId": "${JSON_HOSTNAME}",
	  "entityId": "self",
	  "data": {
		"crashReport": {
		  "timestamp": ${JSON_TIMESTAMP},
		  "pid": "${JSON_PID}",
		  "error": "${JSON_ERROR}",
		  "logs": {
			"hs_err_log": $(parse_log_to_json "${FILE_HS_ERR_LOG}")
		  }
		}
	  }
	}
  ]
}
EOF

}

parse_log_to_json() {
  # Dismiss any error output, which results in the empty string being returned.
  # Another possibility is to redirect error to stdin so the warning shows up for the file.
  cat "$1" 2>/dev/null | python -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

post_crash_data
