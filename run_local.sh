#!/bin/bash
set -a
source .env
set +a

flutter run -d chrome \
  --dart-define=FLAVOR=dev \
  --dart-define=ANTHROPIC_API_KEY=${anthropic_api_key}
