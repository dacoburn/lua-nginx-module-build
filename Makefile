docker_user?=trickyhu
docker_name?=aml2-nginx-luabuild
docker_tag?=latest
docker_opts?=

run-once:
	PWD=$(shell pwd)
	docker run $(docker_opts) --rm -it --name $(docker_name) -v "$(PWD)/output:/output" $(docker_user)/$(docker_name):$(docker_tag)
run:
	PWD=$(shell pwd)
	docker run $(docker_opts) -it --name $(docker_name) -v "$(PWD)/output:/output" $(docker_user)/$(docker_name):$(docker_tag)
build:
	docker build -t $(docker_user)/$(docker_name):$(docker_tag) .
push:
	docker push -t $(docker_user)/$(docker_name):$(docker_tag)