docker_user?=trickyhu
docker_name?=nginx-luabuild
docker_tag?=latest
docker_opts?=
os?=amzl2
PLATFORM=$(os)-$(docker_name)

run:
	PWD=$(shell pwd)
	docker run $(docker_opts) --rm -it --name $(PLATFORM) -v "$(PWD)/output:/output" $(docker_user)/$(PLATFORM):$(docker_tag)
build:
	docker build -f dockerfiles/Dockerfile.$(os) -t $(docker_user)/$(PLATFORM):$(docker_tag) .
push-amzl2:
	docker push $(docker_user)/$(PLATFORM):$(docker_tag)