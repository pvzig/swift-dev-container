#!/usr/bin/env bash
# ---------------------------------------------------------------------------------------------------------
# MIT License
# Docs: https://github.com/pvzig/swift-dev-container/blob/main/README.md
# Maintainer: Peter Zignego

SWIFT_VERSION="${VERSION:-"latest"}"
SWIFT_ROOT="${SWIFT_ROOT:-"/usr/local/bin/swift"}"
USERNAME="${USERNAME:-"${_REMOTE_USER:-"automatic"}"}"

SWIFT_GPG_KEY_URI="https://swift.org/keys/all-keys.asc"

set -e

# Clean up
rm -rf /var/lib/apt/lists/*

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

# Ensure that login shells get the correct path if the user updated the PATH using ENV.
rm -f /etc/profile.d/00-restore-env.sh
echo "export PATH=${PATH//$(sh -lc 'echo $PATH')/\$PATH}" > /etc/profile.d/00-restore-env.sh
chmod +x /etc/profile.d/00-restore-env.sh

# Determine the appropriate non-root user
if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
    USERNAME=""
    POSSIBLE_USERS=("vscode" "node" "codespace" "$(awk -v val=1000 -F ":" '$3==val{print $1}' /etc/passwd)")
    for CURRENT_USER in "${POSSIBLE_USERS[@]}"; do
        if id -u ${CURRENT_USER} > /dev/null 2>&1; then
            USERNAME=${CURRENT_USER}
            break
        fi
    done
    if [ "${USERNAME}" = "" ]; then
        USERNAME=root
    fi
elif [ "${USERNAME}" = "none" ] || ! id -u ${USERNAME} > /dev/null 2>&1; then
    USERNAME=root
fi

# Figure out correct version of a three part version number is not passed
find_version_from_git_tags() {
    local variable_name=$1
    local requested_version=${!variable_name}
    if [ "${requested_version}" = "none" ]; then return; fi
    local repository=$2
    local prefix=${3:-"refs/tags/swift-"}
    local separator=${4:-"."}
    local last_part_optional=${5:-"true"}
    if [ "$(echo "${requested_version}" | grep -o "." | wc -l)" != "2" ]; then
        local escaped_separator=${separator//./\\.}
        local last_part
        if [ "${last_part_optional}" = "true" ]; then
            last_part="(${escaped_separator}[0-9]+)?"
        else
            last_part="${escaped_separator}[0-9]+"
        fi
        local regex="${prefix}\\K[0-9]+${escaped_separator}[0-9]+${last_part}"
        local version_list="$(git ls-remote --tags ${repository} --match "*RELEASE*" | grep -oP "${regex}" | tr -d ' ' | tr "${separator}" "." | sort -rV)"

        if [ "${requested_version}" = "latest" ] || [ "${requested_version}" = "current" ] || [ "${requested_version}" = "lts" ]; then
            declare -g ${variable_name}="$(echo "${version_list}" | head -n 1)"
        else
            set +e
            declare -g ${variable_name}="$(echo "${version_list}" | grep -E -m 1 "^${requested_version//./\\.}([\\.\\s]|$)")"
            set -e
        fi
    fi
    if [ -z "${!variable_name}" ] || ! echo "${version_list}" | grep "^${!variable_name//./\\.}$" > /dev/null 2>&1; then
        echo -e "Invalid ${variable_name} value: ${requested_version}\nValid values:\n${version_list}" >&2
        exit 1
    fi
    echo "${variable_name}=${!variable_name}"
}

apt_get_update() {
    if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
        echo "Running apt-get update..."
        apt-get update -y
    fi
}

yum_update() {
    if [ "$(find /var/lib/yum/history/$(date -I) | wc -l)" = "0" ]; then
        echo "Running yum update..."
        yum update -y
    fi
}

# Checks if packages are installed and installs them if not
check_packages_apt() {
    if ! dpkg -s "$@" > /dev/null 2>&1; then
        apt_get_update
        apt-get -y install --no-install-recommends "$@"
    fi
}

# Checks if packages are installed and installs them if not
check_packages_yum() {
    if ! rpm -q "$@" > /dev/null 2>&1; then
        yum_update
        yum -y install "$@"
    fi
}

# Ubuntu          Debian
# 22.10 kinetic	  12 bookworm/sid
# 22.04 jammy     12 bookworm/sid
# 21.10 impish    11 bullseye/sid
# 21.04 hirsute   11 bullseye/sid
# 20.10 groovy    11 bullseye/sid
# 20.04 focal     11 bullseye/sid
# 19.10 eoan      10 buster/sid
# 19.04 disco     10 buster/sid
# 18.10 cosmic    10 buster/sid
# 18.04 bionic    10 buster/sid

# Ubuntu 18.04, 20.04, 22.04 (official)
# Debian 10, 11 (unofficial)
install_debian_packages() {
    local version=$1
    # Ensure apt is in non-interactive to avoid prompts
    export DEBIAN_FRONTEND=noninteractive
    # Shared packages
    check_packages_apt \
        binutils \
        curl \
        git \
        libc6-dev \
        libedit2 \
        libsqlite3-0 \
        pkg-config \
        tzdata \
        zlib1g-dev \
        gnupg2 \
        ca-certificates

    if [[ "${version}" == "22.04" ]]; then
        check_packages_apt \
            libcurl4-openssl-dev \
            libgcc-9-dev \
            libpython3.8 \
            libsqlite3-0 \
            libstdc++-9-dev \
            libxml2-dev \
            libz3-dev \
            unzip
    elif [ "${version}" == "20.04" ] || [ "${version}" == "11" ]; then
        check_packages_apt \
            libc6-dev \
            libcurl4 \
            libgcc-9-dev \
            libpython2.7 \
            libstdc++-9-dev \
            libxml2 \
            libz3-dev \
            uuid-dev \
            libncurses6
    elif [[ "${version}" == "18.04" ]]; then
        check_packages_apt \
            libcurl4 \
            libgcc-5-dev \
            libpython2.7 \
            libsqlite3-0 \
            libstdc++-5-dev \
            libxml2
    elif [[ "${version}" == "10" ]]; then
        check_packages_apt \
            libcurl4 \
            libpython2.7 \
            libsqlite3-0 \
            libxml2 \
            libncurses5
    else
        echo "Unsupported OS: ${PRETTY_NAME}"
        exit 1
    fi

    if [ "${version}" == "11" ] || [ "${version}" == "10" ]; then
        echo "Swift is not officially supported on Debian and may not work as expected."
    fi

    # Clean up
    rm -rf /var/lib/apt/lists/*
}

# Amazon Linux 2
install_amazon_packages() {
    local version=$1

    if [ "${version}" == "2" ]; then
        check_packages_yum \
            binutils \
            gcc \
            git \
            glibc-static \
            gzip \
            libbsd \
            libcurl \
            libedit \
            libicu \
            libsqlite \
            libstdc++-static \
            libuuid \
            libxml2 \
            tar \
            tzdata \
            gnupg2 \
            ca-certificates
    else
        echo "Unsupported OS: ${PRETTY_NAME}"
        exit 1
    fi
}

# CentOS 7
install_centos_packages() {
    local version=$1

    if [ "${version}" == "7" ]; then
        check_packages_yum \
            binutils \
            gcc \
            git \
            glibc-static \
            libbsd-devel \
            libedit \
            libedit-devel \
            libicu-devel \
            libstdc++-static \
            pkg-config \
            python2 \
            sqlite

        # __block conflicts with clang's __block qualifier
        sed -i -e 's/\*__block/\*__libc_block/g' /usr/include/unistd.h
    else
        echo "Unsupported OS: ${PRETTY_NAME}"
        exit 1
    fi
}

# Bring in ID, VERSION_ID 
. /etc/os-release

if [ "${ID}" == "ubuntu" ] || [ "${ID}" == "debian" ]; then
    install_debian_packages "${VERSION_ID}"
elif [[ "${ID}" == "centos" ]]; then
    install_centos_packages "${VERSION_ID}"
elif [[ "${ID}" == "amzn" ]]; then
    install_amazon_packages "${VERSION_ID}"
else
    echo "Unsupported OS: ${PRETTY_NAME}"
    exit 1
fi

# We use these to construct the download link

if [[ "${ID}" == "debian" ]]; then
    if [[ "${VERSION_ID}" == "10" ]]; then
        platform="ubuntu18.04"
    elif [[ "${VERSION_ID}" == "11" ]]; then
        platform="ubuntu20.04"
    fi
elif [[ "${ID}" == "amzn" ]]; then
    platform="amazonlinux2"
else 
    platform="${ID}${VERSION_ID}"
fi

architecture="$(uname -m)"
# Verify architecture compatibility
if [[ "${architecture}" == "aarch64" ]]; then
    if [ "${platform}" == "ubuntu18.04" ] || [ "${platform}" == "centos7" ]; then
        echo "aarch64 is not supported on ${PRETTY_NAME}."
        exit 1
    fi
    platform="${platform}-${architecture}"
    echo "Supported architecture ${architecture}."
elif  [[ "${architecture}" == "x86_64" ]]; then
    echo "Supported architecture ${architecture}."
else
    echo "Unsupported architecture "${architecture}"."
    exit 1
fi

platform_stripped="$(echo "${platform}" | tr -d '.')"

find_version_from_git_tags SWIFT_VERSION "https://github.com/apple/swift" "refs/tags/swift-"

download_link="https://download.swift.org/swift-${SWIFT_VERSION}-release/$platform_stripped/swift-${SWIFT_VERSION}-RELEASE/swift-${SWIFT_VERSION}-RELEASE-${platform}.tar.gz"

# Install Swift
if [[ "${SWIFT_VERSION}" != "none" ]] && [[ "$(swift --version)" != *"${SWIFT_VERSION}"* ]]; then
    mkdir -p "${SWIFT_ROOT}"
    echo "Downloading Swift ${SWIFT_VERSION} from ${download_link}..."
    set +e
    curl -fsSL -o /tmp/swift.tar.gz "${download_link}"
    curl -fsSL -o /tmp/swift.tar.gz.sig "${download_link}.sig"
    exit_code=$?
    set -e
    if [ "$exit_code" != "0" ]; then
        echo "Download failed."
        exit 1
    fi
    # verify gpg signature
    curl -fsSL "${SWIFT_GPG_KEY_URI}" | gpg --import -
    gpg --keyserver hkp://keyserver.ubuntu.com --refresh-keys Swift
    gpg --verify /tmp/swift.tar.gz.sig || (echo "Failed to verify the GPG signature of swift-${SWIFT_VERSION}-RELEASE-${platform}.tar.gz"; exit 1)
    # unpack
    tar xzf /tmp/swift.tar.gz -C "${SWIFT_ROOT}" --strip-components 1
    # clean up
    rm -rf /tmp/swift.tar.gz
    rm -rf /tmp/swift.tar.gz.sig
    export PATH=${SWIFT_ROOT}/usr/bin:${PATH}
    echo "$(swift --version)"
else
    echo "Swift is already installed with version ${SWIFT_VERSION}. Skipping."
fi

echo "Done!"