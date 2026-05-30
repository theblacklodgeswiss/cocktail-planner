#!/bin/bash
set -a
source .env
set +a

flutter run -d chrome \
  --dart-define=FLAVOR=dev \
  --dart-define=CLAUDE_PROXY_URL=https://cocktail-planer-claude-proxy.the-blacklodge.workers.dev
