docker stack init

docker stack join

docker-compose build

docker login

docker tag (follow how they look in swarm-compose.yml fie)

docker-compose push (if registry is specified in compose file)

change the image names in swarm-compose.yml file.

docker stack deploy -c swarm-compose.yml mpf --with-registry-auth
