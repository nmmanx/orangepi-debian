MYDIR=$(realpath ..)
TAG=orangpi/debian10_build

.PHONY: build shell
build:
	docker build \
		--tag ${TAG} \
		--build-arg USERNAME=$(shell id -un) \
		--build-arg USERID=$(shell id -u) \
		--build-arg GROUPID=$(shell id -g) \
		.

shell:
	docker run --rm -it -v ${MYDIR}:/orangepi-debian -v /usr/bin/qemu-aarch64-static:/usr/bin/qemu-aarch64-static ${TAG}