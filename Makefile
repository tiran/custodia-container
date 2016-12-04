PREFIX = custodia
DOCKER_CMD = docker
DISTRO = f24

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
	rm -f $(CURDIR)/wheels/$(DISTRO)/*.whl
	$(DOCKER_CMD) rm $(PREFIX)-$(DISTRO)-builder >/dev/null 2>&1 || true
	$(DOCKER_CMD) run \
	    --name $(PREFIX)-$(DISTRO)-builder \
	    --user $(shell id -u):$(shell id -g) \
	    -v "$(CURDIR):/buildroot:Z" \
	    -v "$(CURDIR)/wheels:/wheels:Z" \
	    -v "$(CURDIR)/cache:/cache:Z" \
	    $(PREFIX)-$(DISTRO)-build \
	    /buildroot/build.sh

.PHONY: app
app: wheels
	@ls $(CURDIR)/wheels/$(DISTRO)/ipalib*.whl >/dev/null 2>&1 || $(MAKE) wheels
	$(DOCKER_CMD) build \
	    --rm=false \
	    -f $(DISTRO)/app.docker \
	    -v "$(CURDIR)/wheels:/wheels:Z,ro" \
	    -t $(PREFIX)-$(DISTRO)-app .

.PHONY: dockerrun
dockerrun:
	@$(DOCKER_CMD) images | grep -q $(PREFIX)-$(DISTRO)-app || $(MAKE) app
	@$(DOCKER_CMD) rm $(PREFIX)-$(DISTRO) >/dev/null 2>&1|| true
	$(DOCKER_CMD) run \
	    --name $(PREFIX)-$(DISTRO) \
	    -e CREDS_UID=$(shell id -u) -e CREDS_GID=$(shell id -g) \
	    $(PREFIX)-$(DISTRO)-app:latest

.PHONY: clean
clean:
	rm -rf $(CURDIR)/wheels $(CURDIR)/cache
	rm -f $(CURDIR)/packages/ipacommands/ipasetup.py \
	    $(CURDIR)/packages/ipacommands/config.h \
	    $(CURDIR)/packages/ipacommands/Contributors.txt \
	    $(CURDIR)/packages/ipacommands/COPYING \
	    $(CURDIR)/packages/ipacommands/COPYING.openssl
	find $(CURDIR)/packages/custodia \
	     $(CURDIR)/packages/ipacommands \
	     $(CURDIR)/packages/python-nss \
	    -type d -and \( -name 'build' -or -name 'dist' \) | xargs rm -rf
	rm -rf $(CURDIR)/packages/freeipa/ipa*/build
	rm -rf $(CURDIR)/packages/freeipa/ipa*/dist
	rm -f $(CURDIR)/packages/freeipa/config.h.in~
