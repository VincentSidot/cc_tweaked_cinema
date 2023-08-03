#!/bin/bash

NODEJS_PORT=8000
PYTHON_PORT=8001

# Start NodeJS server
cd /app/file_provider
node index.js load /videos --port $NODEJS_PORT &

# Start Python server
cd /app/python
. .venv/bin/activate
python3 src/youtube.py /videos --port $PYTHON_PORT &

# Start Nginx
nginx -g "daemon off;"
