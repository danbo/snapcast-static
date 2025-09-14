# alpine versions: https://alpinelinux.org/releases/
# alpine packages: https://pkgs.alpinelinux.org/packages
# node versions: https://hub.docker.com/_/node/

ARG ALPINE_VERSION="3.22"
ARG NODE_VERSION="22.19.0"

FROM alpine:${ALPINE_VERSION} AS snapcast_build_tools

RUN <<EOF
  # tools to compile snapclient and snapserver
  apk -U add \
    bash nano git \
    boost-dev \
    build-base \
    ccache \
    cmake

  # tools to compile other libraries
  # compile flac, ogg, vorbis to have latest codec versions
  # compile alsa and dbus since there are no static libs available in alpine
  # note: use meson to build dbus since cmake is not producing a static lib despite config
  apk -U add \
    make \
    autoconf \
    automake \
    meson
EOF

FROM snapcast_build_tools AS snapcast_build_deps

RUN <<EOF
    # static libraries used by snapclient and snapserver
    apk -U add \
      openssl-dev openssl-libs-static \
      expat-dev expat-static \
      soxr-dev soxr-static \
      gettext-dev gettext-static \
      avahi-dev avahi-static
EOF

ARG TAR_OPTS="--no-same-owner --extract --file"
ARG DEFAULT_TAR_FORMAT="tar.gz"
ARG DEFAULT_CONFIGURE_FLAGS="--prefix=/usr --enable-static --disable-shared"
ARG CFLAGS="-fPIC -O2"

# flac dependency
ARG LIB_FLAC_NAME=flac
ARG LIB_FLAC_VERSION=1.5.0
ARG LIB_FLAC_FILE=$LIB_FLAC_NAME-$LIB_FLAC_VERSION.tar.xz
ARG LIB_FLAC_URL="https://downloads.xiph.org/releases/$LIB_FLAC_NAME/$LIB_FLAC_FILE"
ARG LIB_FLAC_SHA256=f2c1c76592a82ffff8413ba3c4a1299b6c7ab06c734dee03fd88630485c2b920
RUN <<EOF
  wget $WGET_OPTS -O $LIB_FLAC_FILE "$LIB_FLAC_URL"
  echo "$LIB_FLAC_SHA256 $LIB_FLAC_FILE" | sha256sum -c -
  tar $TAR_OPTS $LIB_FLAC_FILE && cd $LIB_FLAC_NAME-*
  CFLAGS="$CFLAGS" ./configure $DEFAULT_CONFIGURE_FLAGS
  make -j$(nproc) install
EOF

# ogg dependency
ARG LIB_OGG_NAME=libogg
ARG LIB_OGG_VERSION=1.3.6
ARG LIB_OGG_FILE=$LIB_OGG_NAME-$LIB_OGG_VERSION.$DEFAULT_TAR_FORMAT
ARG LIB_OGG_URL="https://downloads.xiph.org/releases/ogg/$LIB_OGG_FILE"
ARG LIB_OGG_SHA256=83e6704730683d004d20e21b8f7f55dcb3383cdf84c0daedf30bde175f774638
RUN <<EOF
  wget $WGET_OPTS -O $LIB_OGG_FILE "$LIB_OGG_URL"
  echo "$LIBLIB_OGG_SHA256 $LIB_OGG_FILE" | sha256sum -c -
  tar $TAR_OPTS $LIB_OGG_FILE && cd $LIB_OGG_NAME-*
  CFLAGS="$CFLAGS" ./configure $DEFAULT_CONFIGURE_FLAGS
  make -j$(nproc) install
EOF

# vorbis dependency
ARG LIB_VORBIS_NAME=libvorbis
ARG LIB_VORBIS_VERSION=1.3.7
ARG LIB_VORBIS_FILE=$LIB_VORBIS_NAME-$LIB_VORBIS_VERSION.$DEFAULT_TAR_FORMAT
ARG LIB_VORBIS_URL="https://downloads.xiph.org/releases/vorbis/$LIB_VORBIS_FILE"
ARG LIB_VORBIS_SHA256=0e982409a9c3fc82ee06e08205b1355e5c6aa4c36bca58146ef399621b0ce5ab
RUN <<EOF
  wget $WGET_OPTS -O $LIB_VORBIS_FILE "$LIB_VORBIS_URL"
  echo "$LIB_VORBIS_SHA256 $LIB_VORBIS_FILE" | sha256sum -c -
  tar $TAR_OPTS $LIB_VORBIS_FILE && cd $LIB_VORBIS_NAME-*
  CFLAGS="$CFLAGS" ./configure $DEFAULT_CONFIGURE_FLAGS
  make -j$(nproc) install
EOF

# opus dependency
ARG LIB_OPUS_NAME=opus
ARG LIB_OPUS_VERSION=1.5.2
ARG LIB_OPUS_FILE=$LIB_OPUS_NAME-$LIB_OPUS_VERSION.$DEFAULT_TAR_FORMAT
ARG LIB_OPUS_URL="https://downloads.xiph.org/releases/$LIB_OPUS_NAME/$LIB_OPUS_FILE"
ARG LIB_OPUS_SHA256=65c1d2f78b9f2fb20082c38cbe47c951ad5839345876e46941612ee87f9a7ce1
RUN <<EOF
  wget $WGET_OPTS -O $LIB_OPUS_FILE "$LIB_OPUS_URL"
  echo "$LIB_OPUS_SHA256 $LIB_OPUS_FILE" | sha256sum -c -
  tar $TAR_OPTS $LIB_OPUS_FILE && cd $LIB_OPUS_NAME-*
  CFLAGS="$CFLAGS" ./configure $DEFAULT_CONFIGURE_FLAGS
  make -j$(nproc) install
EOF

# alsa dependecy
ARG LIB_ALSA_NAME=alsa-lib
ARG LIB_ALSA_VERSION=1.2.14
ARG LIB_ALSA_FILE=$LIB_ALSA_NAME-$LIB_ALSA_VERSION.tar.bz2
ARG LIB_ALSA_URL="http://www.alsa-project.org/files/pub/lib/$LIB_ALSA_FILE"
ARG LIB_ALSA_SHA256=be9c88a0b3604367dd74167a2b754a35e142f670292ae47a2fdef27a2ee97a32
RUN <<EOF
  wget $WGET_OPTS -O $LIB_ALSA_FILE "$LIB_ALSA_URL"
  echo "$LIB_ALSA_SHA256 $LIB_ALSA_FILE" | sha256sum -c -
  tar $TAR_OPTS $LIB_ALSA_FILE && cd $LIB_ALSA_NAME-*
  CFLAGS="$CFLAGS" ./configure $DEFAULT_CONFIGURE_FLAGS
  make -j$(nproc) install
EOF

# dbus dependency - required since there is no alpine dbus-static package available
ARG LIB_DBUS_NAME=dbus
ARG LIB_DBUS_VERSION=1.16.2
ARG LIB_DBUS_FILE=$LIB_DBUS_NAME-$LIB_DBUS_VERSION.tar.xz
ARG LIB_DBUS_URL="https://dbus.freedesktop.org/releases/$LIB_DBUS_NAME/$LIB_DBUS_FILE"
ARG LIB_DBUS_SHA256=0ba2a1a4b16afe7bceb2c07e9ce99a8c2c3508e5dec290dbb643384bd6beb7e2
# https://gitlab.freedesktop.org/dbus/dbus/-/blob/main/INSTALL?ref_type=heads
# https://gitlab.freedesktop.org/dbus/dbus/-/blob/main/meson_options.txt?ref_type=heads
RUN <<EOF 
  wget $WGET_OPTS -O $LIB_DBUS_FILE "$LIB_DBUS_URL"
  echo "$LIB_DBUS_SHA256 $LIB_DBUS_FILE" | sha256sum -c -
  tar $TAR_OPTS $LIB_DBUS_FILE && cd $LIB_DBUS_NAME-*
  meson setup build \
    -Dmodular_tests=disabled \
    --prefix=/usr \
    --default-library=static \
    -Dc_args="$CFLAGS"
  ninja -j$(nproc) -vC build install
EOF
   
FROM snapcast_build_deps AS snapcast_builder

ARG SNAP_VERSION="v0.32.3"
RUN git clone --recursive --depth 1 --branch $SNAP_VERSION https://github.com/badaix/snapcast.git

# https://github.com/badaix/snapcast/blob/develop/doc/build.md
RUN <<EOF
  cd snapcast
  LD_LIBS="avahi-client avahi-common dbus-1 intl"
  sed -i "/^  endif(AVAHI_FOUND)/i\    list(APPEND CLIENT_LIBRARIES $LD_LIBS)" client/CMakeLists.txt
  sed -i "/^  endif(AVAHI_FOUND)/i\    list(APPEND SERVER_LIBRARIES $LD_LIBS)" server/CMakeLists.txt
  cmake -S . -B build \
    -DCMAKE_C_COMPILER_LAUNCHER=ccache \
    -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DOPENSSL_USE_STATIC_LIBS=TRUE \
    -DCMAKE_EXE_LINKER_FLAGS="-fopenmp -static -static-libstdc++ -static-libgcc" \
    -DBUILD_SERVER=ON \
    -DBUILD_CLIENT=ON \
    -DBUILD_WITH_OPUS=ON \
    -DBUILD_WITH_FLAC=ON \
    -DBUILD_WITH_VORBIS=ON \
    -DBUILD_WITH_AVAHI=ON
  cmake --build build --parallel $(nproc)
EOF

FROM node:${NODE_VERSION} AS snapweb_builder

ARG SNAP_WEB_VERSION="v0.3.0"

RUN <<EOF
    apt update && apt install -y git-core
    git clone --recursive --depth 1 --branch ${SNAP_WEB_VERSION} https://github.com/badaix/snapweb.git
    cd snapweb
    npm ci
    npm run build
EOF

FROM alpine:${ALPINE_VERSION} AS deployment_image
LABEL maintainer="danbo"

COPY --from=snapcast_builder snapcast/bin/snapclient /usr/local/bin/
COPY --from=snapcast_builder snapcast/bin/snapserver /usr/local/bin/
COPY --from=snapweb_builder snapweb/dist/ /usr/share/snapserver/snapweb
COPY ./snapserver_0.31.0_default.conf /etc/snapserver.conf

EXPOSE 1704
EXPOSE 1705
EXPOSE 1780

ENTRYPOINT ["snapserver"]
