########################################################################################################################
# Zeek and Spicy

# use the handy-dandy zeek-docker.sh or manually as per these examples

# Monitor a local network interface with Zeek:
#
#   docker run --rm \
#     -v "$(pwd):/zeek-logs" \
#     --network host \
#     --cap-add=NET_ADMIN --cap-add=NET_RAW --cap-add=IPC_LOCK \
#     mmguero/zeek:v6.1.0 \
#     zeekcap -i enp6s0 local

# Analyze a PCAP file with Zeek:
#
#   docker run --rm \
#     -v "$(pwd):/zeek-logs" \
#     -v "/path/containing/pcap:/data:ro" \
#     mmguero/zeek:v6.1.0 \
#     zeek -C -r /data/foobar.pcap local

# Use a custom policy:
#
#   docker run --rm \
#     -v "$(pwd):/zeek-logs" \
#     -v "/path/containing/pcap:/data:ro" \
#     -v "/path/containing/policy/local-example.zeek:/opt/zeek/share/zeek/site/local.zeek:ro" \
#     mmguero/zeek:v6.1.0 \
#     zeek -C -r /data/foobar.pcap local

########################################################################################################################
FROM debian:12-slim as build

ENV DEBIAN_FRONTEND noninteractive
ENV TERM xterm

ARG ZEEK_DIST=Debian_12
ARG ZEEK_BRANCH=v6.1.0
ARG ZEEK_RELEASE_NUM=0
ARG ZEEK_RC=0
ARG ZEEK_DBG=0
ENV ZEEK_DIR $ZEEK_DIST
ENV ZEEK_BRANCH $ZEEK_BRANCH
ENV ZEEK_RELEASE_NUM $ZEEK_RELEASE_NUM
ENV ZEEK_RC $ZEEK_RC
ENV ZEEK_DBG $ZEEK_DBG

ARG SPICY_BRANCH=
ENV SPICY_BRANCH $SPICY_BRANCH

ARG BUILD_FROM_SOURCE=0
ARG BUILD_JOBS=0
ENV BUILD_FROM_SOURCE $BUILD_FROM_SOURCE
ENV BUILD_JOBS $BUILD_JOBS

ENV CCACHE_DIR "/var/spool/ccache"
ENV CCACHE_COMPRESS 1
ENV CMAKE_C_COMPILER clang-14
ENV CC clang-14
ENV CMAKE_CXX_COMPILER clang++-14
ENV CXX clang++-14
ENV CXXFLAGS "-stdlib=libc++ -lc++abi"
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

RUN apt-get -q update && \
    if [ "$BUILD_FROM_SOURCE" = "1" ] || [ ! -z "$SPICY_BRANCH" ]; then \
        echo "Building Zeek ${ZEEK_BRANCH} and Spicy ${SPICY_BRANCH} from source..." && \
        apt-get -y -q --no-install-recommends upgrade && \
        apt-get install -q -y --no-install-recommends \
            bison \
            ca-certificates \
            ccache \
            clang \
            cmake \
            curl \
            flex \
            git \
            libc++-dev \
            libc++abi-dev \
            libfl-dev \
            libgoogle-perftools-dev \
            libgoogle-perftools4 \
            libkrb5-3 \
            libkrb5-dev \
            libmaxminddb-dev \
            libpcap-dev \
            libssl-dev \
            libtcmalloc-minimal4 \
            make \
            ninja-build \
            python3 \
            python3-dev \
            python3-git \
            python3-semantic-version \
            sudo \
            swig \
            zlib1g-dev && \
        mkdir -p /usr/share/src "${CCACHE_DIR}" && \
        git clone \
            --recurse-submodules \
            --shallow-submodules \
            --single-branch \
            --depth 1 \
            --branch "${ZEEK_BRANCH}" \
            "https://github.com/zeek/zeek.git" \
            /usr/share/src/zeek && \
        cd /usr/share/src/zeek/auxil/spicy && \
            if ! [ -z $SPICY_BRANCH ]; then git checkout --force $SPICY_BRANCH; fi && \
            git rev-parse --short HEAD | tee /spicy-sha.txt && \
        cd /usr/share/src/zeek && \
            git rev-parse --short HEAD | tee /zeek-sha.txt && \
            [ "$ZEEK_DBG" = "1" ] && \
                ./configure --prefix=/opt/zeek --generator=Ninja --ccache --enable-perftools --enable-debug || \
                ./configure --prefix=/opt/zeek --generator=Ninja --ccache --enable-perftools && \
            ninja -C build -j "${BUILD_JOBS}" && \
            cd ./build && \
            cpack -G DEB; \
    else \
        apt-get install -q -y --no-install-recommends \
            ca-certificates \
            curl && \
        mkdir -p /usr/share/src/zeek/build && \
        cd /usr/share/src/zeek/build && \
        export ZEEK_VER="$(echo "${ZEEK_BRANCH}-${ZEEK_RELEASE_NUM}" | sed 's/^v//')" && \
        echo "Downloading ${ZEEK_DIST} packages for ${ZEEK_VER}..." && \
        if [ "$ZEEK_RC" = "1" ]; then ZEEK_RC_FN="-rc"; ln -s -r "${ZEEK_DIR}${ZEEK_RC_FN}" "${ZEEK_DIR}"; fi && export ZEEK_RC_FN && \
          curl -fsSL -O -J "https://download.opensuse.org/repositories/security:/zeek/${ZEEK_DIST}/all/zeek${ZEEK_RC_FN}-btest-data_${ZEEK_VER}_all.deb" && \
          curl -fsSL -O -J "https://download.opensuse.org/repositories/security:/zeek/${ZEEK_DIST}/all/zeek${ZEEK_RC_FN}-btest_${ZEEK_VER}_all.deb" && \
          curl -fsSL -O -J "https://download.opensuse.org/repositories/security:/zeek/${ZEEK_DIST}/all/zeek${ZEEK_RC_FN}-client_${ZEEK_VER}_all.deb" && \
          curl -fsSL -O -J "https://download.opensuse.org/repositories/security:/zeek/${ZEEK_DIST}/all/zeek${ZEEK_RC_FN}-zkg_${ZEEK_VER}_all.deb" && \
          curl -fsSL -O -J "https://download.opensuse.org/repositories/security:/zeek/${ZEEK_DIST}/amd64/libbroker${ZEEK_RC_FN}-dev_${ZEEK_VER}_amd64.deb" && \
          curl -fsSL -O -J "https://download.opensuse.org/repositories/security:/zeek/${ZEEK_DIST}/amd64/zeek${ZEEK_RC_FN}_${ZEEK_VER}_amd64.deb" && \
          curl -fsSL -O -J "https://download.opensuse.org/repositories/security:/zeek/${ZEEK_DIST}/amd64/zeek${ZEEK_RC_FN}-core_${ZEEK_VER}_amd64.deb" && \
          curl -fsSL -O -J "https://download.opensuse.org/repositories/security:/zeek/${ZEEK_DIST}/amd64/zeek${ZEEK_RC_FN}-core-dev_${ZEEK_VER}_amd64.deb" && \
          curl -fsSL -O -J "https://download.opensuse.org/repositories/security:/zeek/${ZEEK_DIST}/amd64/zeek${ZEEK_RC_FN}-spicy-dev_${ZEEK_VER}_amd64.deb" && \
          curl -fsSL -O -J "https://download.opensuse.org/repositories/security:/zeek/${ZEEK_DIST}/amd64/zeekctl${ZEEK_RC_FN}_${ZEEK_VER}_amd64.deb" && \
          if [ "$ZEEK_DBG" = "1" ]; then \
              ZEEK_DBG_FN="-dbgsym" && export ZEEK_DBG_FN && \
              curl -fsSL -O -J "https://download.opensuse.org/repositories/security:/zeek/${ZEEK_DIST}/amd64/zeek${ZEEK_RC_FN}-core${ZEEK_DBG_FN}_${ZEEK_VER}_amd64.deb" && \
              curl -fsSL -O -J "https://download.opensuse.org/repositories/security:/zeek/${ZEEK_DIST}/amd64/zeek${ZEEK_RC_FN}-core-dev${ZEEK_DBG_FN}_${ZEEK_VER}_amd64.deb" && \
              curl -fsSL -O -J "https://download.opensuse.org/repositories/security:/zeek/${ZEEK_DIST}/amd64/zeek${ZEEK_RC_FN}-spicy-dev${ZEEK_DBG_FN}_${ZEEK_VER}_amd64.deb" && \
              curl -fsSL -O -J "https://download.opensuse.org/repositories/security:/zeek/${ZEEK_DIST}/amd64/zeekctl${ZEEK_RC_FN}${ZEEK_DBG_FN}_${ZEEK_VER}_amd64.deb"; \
          fi; \
          sha256sum *.deb > /zeek-sha.txt && \
          touch /spicy-sha.txt; \
    fi; \
    ls -lh /usr/share/src/zeek/build/ | tail -n +2 | cat -n

########################################################################################################################
FROM debian:12-slim as base


LABEL maintainer="mero.mero.guero@gmail.com"
LABEL org.opencontainers.image.authors='mero.mero.guero@gmail.com'
LABEL org.opencontainers.image.url='https://github.com/mmguero/zeek-docker'
LABEL org.opencontainers.image.source='https://github.com/mmguero/zeek-docker'
LABEL org.opencontainers.image.title='ghcr.io/mmguero/zeek'
LABEL org.opencontainers.image.description='Dockerized Zeek and Spicy'


ENV DEBIAN_FRONTEND noninteractive
ENV TERM xterm

# put Zeek and Spicy in PATH
ENV ZEEK_DIR "/opt/zeek"
ENV PATH "${ZEEK_DIR}/bin:${PATH}"

# for build
ARG ZEEK_DBG=0
ENV ZEEK_DBG $ZEEK_DBG
ENV CCACHE_DIR "/var/spool/ccache"
ENV CCACHE_COMPRESS 1
ENV SPICY_ZKG_PROCESSES 1
ENV CMAKE_C_COMPILER clang-14
ENV CC clang-14
ENV CMAKE_CXX_COMPILER clang++-14
ENV CXX clang++-14
ENV CXXFLAGS "-stdlib=libc++ -lc++abi"
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

COPY --from=build /usr/share/src/zeek/build/*.deb /tmp/zeek-deb/
COPY --from=build /zeek-sha.txt /zeek-sha.txt
COPY --from=build /spicy-sha.txt /spicy-sha.txt

RUN apt-get -q update && \
    apt-get -y -q --no-install-recommends upgrade && \
    apt-get install -q -y --no-install-recommends \
        bat \
        binutils \
        ca-certificates \
        ccache \
        clang \
        cmake \
        curl \
        fd-find \
        file \
        git \
        libc++-dev \
        libc++abi-dev \
        libcap2-bin \
        libfl-dev \
        libfl2 \
        libgoogle-perftools-dev \
        libgoogle-perftools4 \
        libkrb5-dev \
        libmaxminddb-dev \
        libpcap-dev \
        libssl-dev \
        libtcmalloc-minimal4 \
        make \
        openssl \
        procps \
        psmisc \
        python3 \
        python3-git \
        python3-semantic-version \
        ripgrep \
        rsync \
        tini \
        xxd \
        zlib1g-dev && \
    ( dpkg -i /tmp/zeek-deb/*.deb || true ) && \
    apt-get -f install -q -y --no-install-recommends && \
    zkg autoconfig --force && \
    if [ "$ZEEK_DBG" = "1" ]; then \
        ( find "${ZEEK_DIR}"/lib "${ZEEK_DIR}"/var/lib/zkg \( -path "*/build/*" -o -path "*/CMakeFiles/*" \) -type f -name "*.*" -print0 | xargs -0 -I XXX bash -c 'file "XXX" | sed "s/^.*:[[:space:]]//" | grep -Pq "(ELF|gzip)" && rm -f "XXX"' || true ) ; \
        ( find "${ZEEK_DIR}"/var/lib/zkg/clones -type d -name .git -execdir bash -c "pwd; du -sh; git pull --depth=1 --ff-only; git reflog expire --expire=all --all; git tag -l | xargs -r git tag -d; git gc --prune=all; du -sh" \; ) ; \
        rm -rf "${ZEEK_DIR}"/var/lib/zkg/scratch ; \
        rm -rf "${ZEEK_DIR}"/lib/zeek/python/zeekpkg/__pycache__ ; \
        ( find "${ZEEK_DIR}/" -type f -exec file "{}" \; | grep -Pi "ELF 64-bit.*not stripped" | sed 's/:.*//' | xargs -l -r strip --strip-unneeded ) ; \
        ( find "${ZEEK_DIR}"/lib/zeek/plugins/packages -type f -name "*.hlto" -exec chmod 755 "{}" \; || true ) ; \
    fi && \
    echo "@load packages" >> "${ZEEK_DIR}"/share/zeek/site/local.zeek && \
    cd /usr/lib/locale && \
      ( ls | grep -Piv "^(en|en_US|en_US\.utf-?8|C\.utf-?8)$" | xargs -l -r rm -rf ) && \
    cd /usr/bin && \
        curl -sSL 'https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz' | tar xzvf - >/dev/null 2>&1 && \
        chmod 755 /usr/bin/eza && \
    cd /tmp && \
    apt-get -q -y autoremove && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# configure unprivileged user and runtime parameters
ARG DEFAULT_UID=1000
ARG DEFAULT_GID=1000
ENV DEFAULT_UID $DEFAULT_UID
ENV DEFAULT_GID $DEFAULT_GID
ENV PUSER "zeekcap"
ENV PGROUP "zeekcap"
ENV PUSER_PRIV_DROP true

ARG ZEEK_LOGS_DIR=/zeek-logs
ENV ZEEK_LOGS_DIR $ZEEK_LOGS_DIR

ENV ZEEK_DISABLE_HASH_ALL_FILES ""
ENV ZEEK_DISABLE_LOG_PASSWORDS ""
ENV ZEEK_DISABLE_SSL_VALIDATE_CERTS ""
ENV ZEEK_DISABLE_TRACK_ALL_ASSETS ""
ENV ZEEK_DISABLE_SPICY_DHCP "true"
ENV ZEEK_DISABLE_SPICY_DNS "true"
ENV ZEEK_DISABLE_SPICY_FACEFISH ""
ENV ZEEK_DISABLE_SPICY_HTTP "true"
ENV ZEEK_DISABLE_SPICY_IPSEC ""
ENV ZEEK_DISABLE_SPICY_LDAP ""
ENV ZEEK_DISABLE_SPICY_OPENVPN ""
ENV ZEEK_DISABLE_SPICY_STUN ""
ENV ZEEK_DISABLE_SPICY_TAILSCALE ""
ENV ZEEK_DISABLE_SPICY_TFTP ""
ENV ZEEK_DISABLE_SPICY_WIREGUARD ""

ADD https://raw.githubusercontent.com/mmguero/docker/master/shared/docker-uid-gid-setup.sh /usr/local/bin/docker-uid-gid-setup.sh
ADD login.zeek "${ZEEK_DIR}"/share/zeek/site/
ADD entrypoint.sh /usr/local/bin/

RUN chmod 755 /usr/local/bin/docker-uid-gid-setup.sh && \
    groupadd --gid ${DEFAULT_GID} ${PUSER} && \
    useradd -m --uid ${DEFAULT_UID} --gid ${DEFAULT_GID} ${PUSER} && \
    mkdir -p "${ZEEK_LOGS_DIR}" "${ZEEK_DIR}"/share/zeek/site/intel && \
    touch "${ZEEK_DIR}"/share/zeek/site/intel/__load__.zeek && \
    chown -R ${PUSER}:${PGROUP} "${ZEEK_LOGS_DIR}" "${ZEEK_DIR}"/share/zeek/site/intel && \
    # make a setcap copy of zeek (zeekcap) for listening on an interface
    cp "${ZEEK_DIR}"/bin/zeek "${ZEEK_DIR}"/bin/zeekcap && \
    chown root:${PGROUP} "${ZEEK_DIR}"/bin/zeekcap && \
    setcap 'CAP_NET_RAW+eip CAP_NET_ADMIN+eip CAP_IPC_LOCK+eip' "${ZEEK_DIR}"/bin/zeekcap

VOLUME "${ZEEK_DIR}/share/zeek/site/intel"

WORKDIR "${ZEEK_LOGS_DIR}"

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/docker-uid-gid-setup.sh", "/usr/local/bin/entrypoint.sh"]

########################################################################################################################
FROM base as plus


LABEL maintainer="mero.mero.guero@gmail.com"
LABEL org.opencontainers.image.authors='mero.mero.guero@gmail.com'
LABEL org.opencontainers.image.url='https://github.com/mmguero/zeek-docker'
LABEL org.opencontainers.image.source='https://github.com/mmguero/zeek-docker'
LABEL org.opencontainers.image.title='ghcr.io/mmguero/zeek:plus'
LABEL org.opencontainers.image.description='Dockerized Zeek and Spicy with extra plugins'


ENV DEBIAN_FRONTEND noninteractive
ENV TERM xterm

# put Zeek and Spicy in PATH
ENV ZEEK_DIR "/opt/zeek"
ENV PATH "${ZEEK_DIR}/bin:${PATH}"

# for build
ARG ZEEK_DBG=0
ENV ZEEK_DBG $ZEEK_DBG
ENV CCACHE_DIR "/var/spool/ccache"
ENV CCACHE_COMPRESS 1
ENV SPICY_ZKG_PROCESSES 1
ENV CMAKE_C_COMPILER clang-14
ENV CMAKE_CXX_COMPILER clang++-14

RUN curl -fsSL -o /tmp/zeek_install_plugins.sh "https://raw.githubusercontent.com/mmguero-dev/Malcolm/development/shared/bin/zeek_install_plugins.sh" && \
    bash /tmp/zeek_install_plugins.sh && \
    if [ "$ZEEK_DBG" = "1" ]; then \
        ( find "${ZEEK_DIR}"/lib "${ZEEK_DIR}"/var/lib/zkg \( -path "*/build/*" -o -path "*/CMakeFiles/*" \) -type f -name "*.*" -print0 | xargs -0 -I XXX bash -c 'file "XXX" | sed "s/^.*:[[:space:]]//" | grep -Pq "(ELF|gzip)" && rm -f "XXX"' || true ) ; \
        ( find "${ZEEK_DIR}"/var/lib/zkg/clones -type d -name .git -execdir bash -c "pwd; du -sh; git pull --depth=1 --ff-only; git reflog expire --expire=all --all; git tag -l | xargs -r git tag -d; git gc --prune=all; du -sh" \; ) ; \
        rm -rf "${ZEEK_DIR}"/var/lib/zkg/scratch ; \
        rm -rf "${ZEEK_DIR}"/lib/zeek/python/zeekpkg/__pycache__ ; \
        ( find "${ZEEK_DIR}/" -type f -exec file "{}" \; | grep -Pi "ELF 64-bit.*not stripped" | sed 's/:.*//' | xargs -l -r strip --strip-unneeded ) ; \
        ( find "${ZEEK_DIR}"/lib/zeek/plugins/packages -type f -name "*.hlto" -exec chmod 755 "{}" \; || true ) ; \
    fi && \
    rm -rf /tmp/zeek_install_plugins.sh
