#!/bin/bash
set -xe

# Create the package - assumes new gem2deb is in the packaging repo
git checkout origin/deb/${repo} -b local
cd dependencies/${os}
mkdir build-${project}
cd build-${project}

# Import variables from the project, allowing it to override gem2deb behaviour
if [ -e ../${project}/build_vars.sh ]; then
  . ../${project}/build_vars.sh
fi

# Figure out package version and gem2deb it
VERSION=$(head -n1 ../${project}/changelog|awk '{print $2}'|sed 's/(//;s/)//'|cut -f1 -d-|cut -d: -f2)
gem fetch ${project} -v "=${VERSION}"
../../gem2deb ${project}-${VERSION}.gem --debian-subdir ../${project} --only-source-dir

# Should only be one dir generated by gem2deb
DIR=$(find -maxdepth 1 -type d -not -name '.')
echo $DIR
cd $DIR

# Add changelog entry if this is a git build
if [ x$gitrelease = xtrue ]; then
  PACKAGE_NAME=$(head -n1 debian/changelog|awk '{print $1}')
  LAST_COMMIT=$(git rev-list HEAD|/usr/bin/head -n 1)
  DATE=$(date -R)
  RELEASE="${VERSION}-${os}+scratchbuild${BUILD_TIMESTAMP}"
  MAINTAINER="${repoowner} <no-reply@theforeman.org>>"
  mv debian/changelog debian/changelog.tmp
  echo "$PACKAGE_NAME ($RELEASE) UNRELEASED; urgency=low

  * Automatically built package based on the state of
    foreman-packaging at commit $LAST_COMMIT

 -- $MAINTAINER  $DATE
" > debian/changelog

  cat debian/changelog.tmp >> debian/changelog
  rm -f debian/changelog.tmp
fi

# Build the package for the OS using pbuilder
# needs sudo as pedebuild uses loop and bind mounts
if [ $arch = x86 ]; then
  sudo pdebuild-${os}64
fi

# Only build on non-x86 arches when the binary differs
if grep -qe "Architecture:\s\+any" debian/control; then
  if [ $arch != x86 ]; then
    sudo pdebuild-${os}
  else
    # we are on x86 and build i386 DEBs (for dependencies, but not for the heavy weight core packages)
    sudo pdebuild-${os}32
  fi
fi

# Cleanup, pdebuild uses root
sudo chown -R jenkins:jenkins $WORKSPACE
