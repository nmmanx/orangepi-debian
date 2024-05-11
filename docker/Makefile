MYDIR=$(realpath ..)
TAG=orangpi/debian10_build

FREE_LOOP_DEV=$(shell losetup -f)

.PHONY: build shell
build:
	docker build \
		--tag ${TAG} \
		--build-arg USERNAME=$(shell id -un) \
		--build-arg USERID=$(shell id -u) \
		--build-arg GROUPID=$(shell id -g) \
		.

shell:
	# CAP_SYS_ADMIN is needed for mounting /proc and /sys after chroot
	docker run \
		--privileged \
		--cap-add=CAP_SYS_ADMIN \
		-v /dev:/dev \
		-v ${MYDIR}:/orangepi-debian \
		-v /usr/bin/qemu-aarch64-static:/usr/bin/qemu-aarch64-static \
		-e FREE_LOOP_DEV=$(FREE_LOOP_DEV) \
		--rm -it \
		${TAG}
