# DO NOT MODIFY - it is auto written from duckietown-env-developer

default_arch=arm32v7
arch=$(default_arch)
default_machine=unix:///var/run/docker.sock
machine=$(default_machine)
pull=0

root_dir:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
code_dir:=$(root_dir)/../

branch=$(shell git -C "$(code_dir)" rev-parse --abbrev-ref HEAD)

# name of the repo
repo=$(shell basename -s .git `git -C "$(code_dir)" config --get remote.origin.url`)

default_tag=duckietown/$(repo):$(branch)
tag=duckietown/$(repo):$(branch)-$(arch)

labels=$(shell $(root_dir)/labels.py "$(code_dir)")

_build: no_cache=0
_build-no-cache: no_cache=1

_build _build-no-cache:
	docker \
		-H=$(machine) \
		build \
			--pull=$(pull) \
			$(labels) \
			-t $(tag) \
			--build-arg ARCH=$(arch) \
			--no-cache=$(no_cache) \
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
