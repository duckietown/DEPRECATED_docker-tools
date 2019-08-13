# DO NOT MODIFY - contact Andrea F. Daniele (afdaniele@ttic.edu) if you need to

default_arch=arm32v7
arch=$(default_arch)
default_machine=unix:///var/run/docker.sock
arm_binfmt=/proc/sys/fs/binfmt_misc/qemu-arm
machine=$(default_machine)
pull=0
nocache=0

# root dir and code dir
root_dir:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
code_dir:=$(root_dir)/../

# name of the branch
branch=$(shell git -C "$(code_dir)" rev-parse --abbrev-ref HEAD)

# name of the repo
repo=$(shell basename -s .git `git -C "$(code_dir)" config --get remote.origin.url`)

# docker image tags
default_tag=duckietown/$(repo):$(branch)
tag=duckietown/$(repo):$(branch)-$(arch)

# get labels for the image
labels=$(shell $(root_dir)/labels.py "$(code_dir)")

_env_check:
	@# check if binfmt was registered for the target architecture
	@if [ "$(arch)" = "$(default_arch)" ]; then \
		if [ ! -f "$(arm_binfmt)" ]; then \
			echo "The module 'binfmt_misc' does not appear to be registered with your kernel."; \
			echo "Registering..."; \
			docker run --rm --privileged multiarch/qemu-user-static:register --reset; \
			echo "Done!"; \
		else \
			if [ ! `head -1 $(arm_binfmt)` = "enabled" ]; then \
				echo "The module 'binfmt_misc' for \"arm\" architecture is not enabled. Please, enable it first."; \
				echo "Exiting..."; \
				exit 1; \
			fi \
		fi \
	fi

_build: _env_check
	docker \
		-H=$(machine) \
		build \
			--pull=$(pull) \
			$(labels) \
			-t $(tag) \
			--build-arg ARCH=$(arch) \
			--no-cache=$(nocache) \
			"$(code_dir)" \
	| tee /dev/tty \
	| python3 $(root_dir)/image_analysis.py --machine "$(machine)"

	@if [ "$(arch)" = "$(default_arch)" ]; then \
		echo "Tagging image $(tag) as $(default_tag)."; \
		docker -H=$(machine) tag $(tag) $(default_tag); \
		echo "Done!"; \
	else \
		echo "Tagging image $(tag) as $(default_tag)-no-arm."; \
		docker -H=$(machine) tag $(tag) $(default_tag)-no-arm; \
		echo "Done!"; \
	fi

_push:
	docker push $(tag)

	@if [ "$(arch)" = "$(default_arch)" ]; then \
		docker -H=$(machine) push $(default_tag); \
	else \
		docker -H=$(machine) push $(default_tag)-no-arm; \
	fi
