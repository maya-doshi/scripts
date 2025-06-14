#!/usr/bin/env sh

# script to post to memos and bsky
# requires jq, curl and an editor

URL=''            # fill this
TOKEN=''          # fill this
VISIBILITY="PRIVATE"

PDSHOST=''        # fill this
BSKY_HANDLE=''    # fill this
BSKY_PASS=''      # fill this
BSKY_TOKEN=''     # leave empty

PUBSKY_PDSHOST='' # fill this
PUBSKY_HANDLE=''  # fill this
PUBSKY_PASS=''    # fill this
PUBSKY_TOKEN=''   # leave empty

usage() {
  echo "Usage: $0 -m 'memo' [-p]"
  echo "  -p    make public"
  echo "  -b    bsky"
  echo "  -x    pubsky"
  echo "  -m    include memo in quote after this"
  exit 1
}

# 1 -> pds url
# 2 -> handle
# 3 -> pass
get_bsky_token() {
  curl --silent -X POST $1/xrpc/com.atproto.server.createSession \
    -H "Content-Type: application/json" \
    -d '{"identifier": "'"$2"'", "password": "'"$3"'"}' | \
  jq -r '.accessJwt'
}

# 1 -> pds url
# 2 -> handle
# 3 -> token
# 4 -> memo
post_bsky() {
  curl --silent -X POST $1/xrpc/com.atproto.repo.createRecord \
    -H "Authorization: Bearer $3" \
    -H "Content-Type: application/json" \
    --data "$(jq -n --arg content "$4" --arg handle "$2" --arg time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{repo: $handle, collection: "app.bsky.feed.post", record: {text: $content, createdAt: $time}}')" | \
   jq
}

while getopts "pbxm:" opt; do
  case ${opt} in
    m )
      MEMO="$OPTARG"
      ;;
    p )
      VISIBILITY="PUBLIC"
      ;;
    b )
      BSKY_TOKEN=$(get_bsky_token ${PDSHOST} ${BSKY_HANDLE} ${BSKY_PASS})
      ;;
    x )
      PUBSKY_TOKEN=$(get_bsky_token $PUBSKY_PDSHOST $PUBSKY_HANDLE $PUBSKY_PASS)
      echo $PUBSKY_TOKEN
      ;;
    \? )
      usage
      ;;
  esac
done

if [ -z "$MEMO" ]; then
  if [ -z "$EDITOR" ]; then
    echo "EDITOR env var not set, using vim"
    EDITOR="vim"
  fi

  TEMP_FILE=$(mktemp)
  $EDITOR "$TEMP_FILE"

  MEMO=$(<"$TEMP_FILE")

  rm "$TEMP_FILE"
fi

if [ -z "$MEMO" ]; then
  echo "memo cant be empty"
  exit 1
fi

## 1/4th chance :D
# if [ $RANDOM -lt 4096 ] && [ -n "$BSKY_TOKEN" ]; then
if [ -n "$BSKY_TOKEN" ]; then
  echo BSKY
  post_bsky $PDSHOST $BSKY_HANDLE $BSKY_TOKEN "$MEMO"
fi

if [ -n "$PUBSKY_TOKEN" ]; then
  echo PUBSKY
  post_bsky $PUBSKY_PDSHOST $PUBSKY_HANDLE $PUBSKY_TOKEN "$MEMO"
fi

curl $URL/api/v1/memos \
  --silent \
  --request POST \
  --header 'Content-Type: text/plain;charset=UTF-8' \
  --header "Authorization: Bearer $TOKEN" \
  --data "$(jq -n --arg content "$MEMO" --arg visibility "$VISIBILITY" '{content: $content, visibility: $visibility}')" | \
jq -r '"\(.visibility):\n\(.content)"'
