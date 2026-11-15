#!/usr/bin/env sh

# Deprecated, kept so that existing "source" lines in shell profiles do not fail.
# bin/exec-env sets CATALINA_HOME for the selected version on every catalina.sh
# call; a value exported once at shell startup went stale after switching versions.
