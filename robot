#!/usr/bin/env bash

set -e
set -u

### globals ####################################################################

this_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

### helpers ####################################################################

wait_zalenium_started() {
  local done_msg="Zalenium is now ready!"
  while ! docker logs zalenium | grep "$done_msg" >/dev/null; do
    echo -n '.'
    sleep 0.2
  done
}

### main #######################################################################

echo "### Pulling Docker image 'elgalu/selenium'"
docker pull elgalu/selenium

if ! docker top zalenium &>/dev/null ; then
  echo -e "\n\n### Starting Zalenium in background"
  docker run -d --rm -ti --name zalenium -p 4444:4444 \
    -e DOCKER=1.11 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$this_path/videos":/home/seluser/videos \
    dosel/zalenium start \
      --chromeContainers 0 \
      --firefoxContainers 0 \
      --maxDockerSeleniumContainers 4 \
      --screenWidth 1366 --screenHeight 768 \
      --timeZone "Europe/Helsinki" \
      --videoRecordingEnabled true \
      --sauceLabsEnabled false \
      --browserStackEnabled false \
      --testingBotEnabled false \
      --startTunnel false \
      --sendAnonymousUsageInfo false

  trap "echo '### Stopping Zalenium...'; docker stop zalenium &>/dev/null ; exit 1" SIGINT SIGTERM

  echo -e "\n\n### Waiting Zalenium to be started in background"
  wait_zalenium_started
fi

echo -e "\n\n### Building docker image, including copying the tests"
docker build -t rf:latest .

echo -e "\n\n### Running the tests now"
docker run --rm -ti --name rf \
  -v "$this_path/results":/home/robot/results \
  -e ZALENIUM_HOST=${ZALENIUM_HOST:-zalenium} \
  --link zalenium:zalenium \
  rf:latest "${@:-tests}"
