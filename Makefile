PREFIX = custodia
DOCKER_CMD = docker
DISTRO = f25

VOL_SUFFIX=$(shell getenforce >/dev/null 2>&1 && echo ':Z' || echo '')

.NOTPARALLEL:

all: wheels app

.PHONY: baseimage
baseimage:
	$(DOCKER_CMD) build \
	    -f $(DISTRO)/base.docker \
	    -t $(PREFIX)-$(DISTRO)-base .

.PHONY: buildimage
buildimage: baseimage
	$(DOCKER_CMD) build \
	    --rm=false \
	    -f $(DISTRO)/build.docker \
	    -t $(PREFIX)-$(DISTRO)-build .

.PHONY: wheels
wheels:
	$(DOCKER_CMD) images | grep -q $(PREFIX)-$(DISTRO)-build || $(MAKE) buildimage
	mkdir -p $(CURDIR)/wheels/$(DISTRO) $(CURDIR)/cache
	$(DOCKER_CMD) rm $(PREFIX)-$(DISTRO)-builder >/dev/null 2>&1 || true
	$(DOCKER_CMD) run \
	    --name $(PREFIX)-$(DISTRO)-builder \
	    --user $(shell id -u):$(shell id -g) \
	    -v "$(CURDIR):/buildroot:Z" \
	    -v "$(CURDIR)/wheels:/wheels:Z" \
	    -v "$(CURDIR)/cache:/cache:Z" \
	    $(PREFIX)-$(DISTRO)-build \
	    /buildroot/build_wheels.sh

.PHONY: app
app: wheels
	@ls $(CURDIR)/wheels/$(DISTRO)/ipalib*.whl >/dev/null 2>&1 || $(MAKE) wheels
	$(DOCKER_CMD) build \
	    -f $(DISTRO)/app.docker \
	    -t $(PREFIX)-$(DISTRO)-app .

.PHONY: dockerrun
dockerrun:
	@$(DOCKER_CMD) images | grep -q $(PREFIX)-$(DISTRO)-app || $(MAKE) app
	@$(DOCKER_CMD) rm $(PREFIX)-$(DISTRO) >/dev/null 2>&1|| true
	$(DOCKER_CMD) run \
	    --name $(PREFIX)-$(DISTRO) \
	    -e CREDS_UID=$(shell id -u) -e CREDS_GID=$(shell id -g) \
	    $(PREFIX)-$(DISTRO)-app:latest

.PHONY: dockertest
dockertest:
	@$(DOCKER_CMD) images | grep -q $(PREFIX)-$(DISTRO)-app || $(MAKE) app
	@$(DOCKER_CMD) rm $(PREFIX)-$(DISTRO) >/dev/null 2>&1|| true
	$(DOCKER_CMD) run \
	    --name $(PREFIX)-$(DISTRO) \
	    -v $(CURDIR)/tests.sh:/tmp/tests.sh$(VOL_SUFFIX) \
	    $(PREFIX)-$(DISTRO)-app:latest \
	    sh /tmp/tests.sh

.PHONY: clean
clean:
	rm -rf $(CURDIR)/wheels
	rm -f $(CURDIR)/packages/ipacommands/ipasetup.py \
	    $(CURDIR)/packages/ipacommands/config.h \
	    $(CURDIR)/packages/ipacommands/Contributors.txt \
	    $(CURDIR)/packages/ipacommands/COPYING \
	    $(CURDIR)/packages/ipacommands/COPYING.openssl
	find $(CURDIR)/packages/custodia \
	     $(CURDIR)/packages/ipacommands \
	    -type d -and \( -name 'build' -or -name 'dist' \) | xargs rm -rf
	rm -rf $(CURDIR)/packages/freeipa/ipa*/build
	rm -rf $(CURDIR)/packages/freeipa/ipa*/dist
	rm -f $(CURDIR)/packages/freeipa/config.h.in~

.PHONY: cleandocker
cleandocker:
	$(DOCKER_CMD) rm $(PREFIX)-$(DISTRO) || true
	$(DOCKER_CMD) rm $(PREFIX)-$(DISTRO)-builder || true
	$(DOCKER_CMD) rmi $(PREFIX)-$(DISTRO)-app || true
	$(DOCKER_CMD) rmi $(PREFIX)-$(DISTRO)-build || true
	$(DOCKER_CMD) rmi $(PREFIX)-$(DISTRO)-base || true

.PHONY: realclean
realclean: clean cleandocker
	rm -rf $(CURDIR)/cache

