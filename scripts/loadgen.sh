#!/bin/sh
# Simple continuous load generator for the fastapi-demo service.
# Hits a mix of endpoints so Prometheus records rates, latencies, and status codes.
URL="${URL:-http://fastapi-demo.fastapi-demo.svc.cluster.local}"
i=0
while true; do
  i=$((i + 1))
  # create
  curl -s -o /dev/null -X POST "$URL/tasks/" \
    -H "Content-Type: application/json" \
    -d "{\"title\":\"task-$i\",\"description\":\"load test $i\"}"
  # list
  curl -s -o /dev/null "$URL/tasks/"
  # read one (may 404 sometimes -> generates error status codes too)
  curl -s -o /dev/null "$URL/tasks/1"
  # health + root
  curl -s -o /dev/null "$URL/health"
  curl -s -o /dev/null "$URL/"
  # update
  curl -s -o /dev/null -X PUT "$URL/tasks/1" \
    -H "Content-Type: application/json" \
    -d '{"completed":true}'
  # delete the one we created
  curl -s -o /dev/null -X DELETE "$URL/tasks/$i"
  sleep 0.05
done
