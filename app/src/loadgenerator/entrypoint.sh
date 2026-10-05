#!/bin/sh

locust --host="http://${FRONTEND_ADDR:-localhost:8080}" --headless -u "${USERS:-10}" -r "${RATE:-1}" 2>&1
