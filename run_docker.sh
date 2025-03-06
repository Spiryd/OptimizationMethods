docker stop glpk
docker rm glpk
docker build . -t glpk --network host
docker run --name glpk -d -i -t glpk /bin/sh

# Remove dangling images if any exist
if [ "$(docker images -f dangling=true -q)" ]; then
  docker rmi $(docker images -f dangling=true -q)
fi

docker exec -it glpk /bin/sh