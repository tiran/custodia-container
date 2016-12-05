# Custodia container builder

[![Build Status](https://travis-ci.org/tiran/custodia-container.svg?branch=master)](https://travis-ci.org/tiran/custodia-container)

Christian Heimes <cheimes@redhat.com>

https://github.com/latchset/custodia/

## Images / containers

The base image ```custodia-f24-base``` contains common dependencies for
the wheel builder and application container, e.g. shared libraries, programs
and a virtual env.

The wheel builder container ```custodia-f24-build``` has build infrastructure
like compiler, headers and wheel package. It's used to create universal and
binary wheels for the application image. It's derived from the base
image.

Python wheels and config files are installed in the ```custodia-f24-app```
image.


## Build

* run ```git submodule init```
* make

### make targets

* **baseimage** creates base image

* **buildimage** creates build image

* **wheels** runs build.sh in the build image

* **app** installs wheels in app image

* **dockerrun** runs a test app image

* **clean** cleanup

### make flags

* **DISTRO** use ```DISTRO=yakkety``` to build a Yakkety Yak container (experimental).


## References

* https://glyph.twistedmatrix.com/2015/03/docker-deploy-double-dutch.html

* http://blog.dscpl.com.au/2016/12/what-user-should-you-use-to-run-docker.html

* http://www.projectatomic.io/docs/docker-image-author-guidance/