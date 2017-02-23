#!/bin/sh
set -ex

. /venv/bin/activate

/venv/bin/custodia-cli --help
/venv/bin/custodia --help

/venv/bin/python -c 'from custodia.ipa import vault'
/venv/bin/python -c 'from ipalib import api; api.bootstrap()'
