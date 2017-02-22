#!/bin/bash
set -e

PACKAGES=/buildroot/packages
VENV=/venv

. ${VENV}/bin/activate

# upstream python-nss has a build bug
rm -rf ${PACKAGES}/python-nss/build ${PACKAGES}/python-nss/dist
${VENV}/bin/pip wheel ${PACKAGES}/python-nss

# custodia
rm -rf ${PACKAGES}/custodia/build ${PACKAGES}/custodia/dist
${VENV}/bin/pip wheel ${PACKAGES}/custodia

# ipalib, ipaclient; depends on custodia
pushd ${PACKAGES}/freeipa
rm -f configure Makefile config.status
if [ ! -e configure ]; then
    autoreconf -if
fi
./configure \
    --silent \
    --disable-pylint \
    --without-jslint \
    --disable-server \
    --with-ipaplatform=base
make clean bdist_wheel PYTHON=${VENV}/bin/python
${VENV}/bin/pip wheel dist/wheels/ipa*.whl
popd

# ipa-getkeytab
pushd ${PACKAGES}/ipacommands
rm -rf ${PACKAGES}/ipacommands/build ${PACKAGES}/ipacommands/dist
for name in ipasetup.py config.h Contributors.txt COPYING COPYING.openssl; do
    cp -p ${PACKAGES}/freeipa/${name} ${PACKAGES}/ipacommands/
done
python setup.py bdist_wheel
${VENV}/bin/pip wheel dist/*.whl
popd

# custodia.ipa depends on ipalib
rm -rf ${PACKAGES}/custodia.ipa/build ${PACKAGES}/custodia.ipa/dist
${VENV}/bin/pip wheel ${PACKAGES}/custodia.ipa
