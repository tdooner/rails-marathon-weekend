#!/usr/bin/env bash -e

if [ $# -lt 1 ]; then
  echo "usage: $0 [marathon_ip]"
  exit 1
fi

deploy=$(git sha1)
docker_tag="tdooner/tom-mesos:${deploy}"
marathon_ip=$1

echo "Building and pushing Docker image ${docker_tag}..."
pushd rails-marathon-test >/dev/null
docker build -t $docker_tag . &&
docker push $docker_tag
popd >/dev/null

echo "Updating rails-marathon.json..."
last_tag=$(cat rails-marathon.json | jq -r '.["container"]["docker"]["image"]')
sed -i '' -e "s#${last_tag}#${docker_tag}#" rails-marathon.json

echo "Deploying new Docker image to marathon..."
curl -XPOST \
  -d @rails-marathon.json \
  -H"Content-Type: application/json" \
  http://$marathon_ip:8080/v2/apps

echo "Done!"
