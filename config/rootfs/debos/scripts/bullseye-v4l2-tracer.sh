#!/bin/bash

# Important: This script is run under QEMU

set -e

# Build-depends needed to build the test suites, they'll be removed later
BUILD_DEPS="\
    build-essential \
    ca-certificates \
    git \
    gettext \
    libasound2-dev \
    libelf-dev  \
    libglib2.0-dev \
    libjpeg62-turbo-dev \
    libjson-c-dev \
    libtool \
    libudev-dev  \
    meson \
"

apt-get install --no-install-recommends -y  ${BUILD_DEPS}

BUILDFILE=/test_suites.json
echo '{  "tests_suites": [' >> $BUILDFILE

# Build v4l2-tracer
########################################################################

src="/tmp/tests/v4l2-tracer"
mkdir -p "$src" && cd "$src"

git clone --depth=1 https://gitlab.collabora.com/dbrouwer/v4l-utils.git .
git pull origin v4l2-tracer/conformance

echo '    {"name": "v4l2-tracer", "git_url": "https://gitlab.collabora.com/dbrouwer/v4l-utils.git", "git_commit": ' \"`git rev-parse HEAD`\" '}' >> $BUILDFILE

meson setup \
 -Dprefix="$src"/usr/ \
 -Dudevdir="$src"/usr/lib/udev \
 -Dgconvsysdir="$src"/usr \
 -Dlibv4l1subdir="$src"/usr \
 -Dlibv4l2subdir="$src"/usr \
 -Dlibv4lconvertsubdir="$src"/usr \
 -Dsystemdsystemunitdir="$src"/usr \
 -Dstrip=true \
 -Dbpf=disabled \
 -Ddoxygen-doc=disabled \
 -Ddoxygen-html=false \
 -Ddoxygen-man=false \
 -Dgconv=disabled \
 -Dlibdvbv5=disabled \
 -Dqv4l2=disabled \
 -Dqvidcap=disabled \
 -Dv4l-plugins=false \
 -Dv4l-wrappers=false \
 -Dv4l2-compliance-libv4l=false \
 -Dv4l2-ctl-libv4l=false \
 -Dv4l2-tracer=enabled \
build/

ninja -C build/ install

# Copy the v4l2-tracer executable
cp -a "$src"/usr/bin/v4l2-tracer /usr/bin/

# Copy the v4l2-tracer's library and set the path to its new location
cp -a "$src"/usr/lib64/libv4l2tracer.so /usr/lib64/
echo 'export LD_PRELOAD=/usr/lib64/libv4l2tracer.so' >> ~/.bashrc

# Copy the v4l2-tracer's m2m conformance test data and set the path to its new location
mkdir -p /usr/share/v4l2-m2m-conformance
cp -a "$src"/usr/share/v4l2-m2m-conformance/* /usr/share/v4l2-m2m-conformance/
echo 'export V4L2_TRACER_CONFORMANCE_DATA_PATH=/usr/share/v4l2-m2m-conformance/' >> ~/.bashrc

echo '  ]}' >> $BUILDFILE

# Build v4l2-get-device
########################################################################

echo "Building v4l2-get-device"

dir="/tmp/tests/v4l2-get-device"
url="https://gitlab.collabora.com/gtucker/v4l2-get-device.git"

mkdir -p "$dir" && cd "$dir"
git clone --depth=1 "$url" .
make
strip v4l2-get-device
make install

########################################################################
# Cleanup: remove files and packages we don't want in the images       #
########################################################################
cd /tmp
rm -rf /tmp/tests

apt-get remove --purge -y ${BUILD_DEPS}
apt-get remove --purge -y perl-modules-5.32
apt-get autoremove --purge -y
apt-get clean

# re-add some stuff that is removed by accident
apt-get install -y initramfs-tools
