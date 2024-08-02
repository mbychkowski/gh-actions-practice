#!/bin/bash
cd "$(dirname "$0")"

EXT_IP=$1

RED="\e[31m"
GREEN="\e[32m"
ENDCOLOR="\e[0m"


echo -e "\nRunning e2e tests for GenAI Quickstsart..." &> tests.log
tcnt=0
ttotal=1

########################
######## TEST 1 ########
########################
# It returns value from genai api when requesting text prompt from VertextAI.

((tcnt=tcnt+1))

res=$(curl -s -X 'POST' "http://${EXT_IP}/genai/text" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{"prompt": "Who are the founders of Google?"}')

if [[ ${res} == *"Larry Page"* ]]; then
  echo -e "[${tcnt}/${ttotal}] ${GREEN}PASS${ENDCOLOR}: Received valid response from VertexAI text" &>> tests.log
else
  echo -e "[${tcnt}/${ttotal}] ${RED}FAIL${ENDCOLOR}: Invalid or noresponse from VertexAI text" &>> tests.log
fi

########################
######## TEST 2 ########
########################
# It returns value from genai api when requesting text prompt from VertextAI.

cat tests.log