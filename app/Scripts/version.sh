#!/usr/bin/env bash
# Single source of truth for app versions and build numbers.
#
# Every build/packaging script sources this file. Override at build time with the
# GLOBE_VERSION / GLOBE_BUILD environment variables (e.g. from CI); otherwise these
# defaults are used.
#
# The two distribution channels intentionally use different version trains:
#   - Direct (Developer ID): public beta train, may carry a "-beta.N" suffix.
#   - App Store: stable train; marketing version has no pre-release suffix and the
#     build number must strictly increase with every upload to App Store Connect.

# Direct / Developer ID channel.
GLOBE_DEFAULT_VERSION="0.1.0-beta.26"
GLOBE_DEFAULT_BUILD="1"

# App Store channel.
GLOBE_DEFAULT_APPSTORE_VERSION="0.1.0"
GLOBE_DEFAULT_APPSTORE_BUILD="44"
