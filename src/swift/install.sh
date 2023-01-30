#!/usr/bin/env bash
# ---------------------------------------------------------------------------------------------------------
# MIT License
# Docs: https://github.com/pvzig/swift-dev-container/blob/main/README.md
# Maintainer: Peter Zignego

SWIFT_VERSION="${VERSION:-"latest"}"
USERNAME="${USERNAME:-"${_REMOTE_USER:-"automatic"}"}"

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
    local platform=$2
    local architecture=$3
    local repository=$4
    local prefix=${5:-"refs/tags/swift-"}
    local separator=${6:-"."}
    local last_part_optional=${7:-"true"}
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

        if [[ "${requested_version}" = "latest" ]]; then
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

    resolve_distribution_swift_version_matrix SWIFT_VERSION "${platform}" "${architecture}"
    echo "${variable_name}=${!variable_name}"
}

# Certain versions of Swift are only supported on certain distributions (see matrix below). 
# We round up to match the host distro with the closest supported version of Swift.

# |-----------------------------------------x86--------------------------------------------|
# | Swift Version | Ubuntu 18.04 | Ubuntu 20.04 | Ubuntu 22.04 | CentOS 7 | Amazon Linux 2 |
# | 5.0           | ✅           | ❌           | ❌           | ❌       | ❌             |
# | 5.1           | ✅           | ❌           | ❌           | ❌       | ❌             |
# | 5.2           | ✅           | ❌           | ❌           | ❌       | ❌             |
# | 5.2.4         | ✅           | ✅           | ❌           | ❌       | ✅             |
# | 5.2.5         | ✅           | ✅           | ❌           | ✅       | ✅             |
# | 5.3           | ✅           | ✅           | ❌           | ✅       | ✅             |
# | 5.4           | ✅           | ✅           | ❌           | ✅       | ✅             |
# | 5.5           | ✅           | ✅           | ❌           | ✅       | ✅             |
# | 5.6           | ✅           | ✅           | ❌           | ✅       | ✅             |
# | 5.7           | ✅           | ✅           | ✅           | ✅       | ✅             |
# |----------------------------------------------------------------------------------------|
# |--------------------------------------aarch64-------------------------------------------|
# | Swift Version | Ubuntu 18.04 | Ubuntu 20.04 | Ubuntu 22.04 | CentOS 7 | Amazon Linux 2 |
# | 5.0           | ❌           | ❌           | ❌           | ❌       | ❌             |
# | 5.1           | ❌           | ❌           | ❌           | ❌       | ❌             |
# | 5.2           | ❌           | ❌           | ❌           | ❌       | ❌             |
# | 5.2.4         | ❌           | ❌           | ❌           | ❌       | ❌             |
# | 5.2.5         | ❌           | ❌           | ❌           | ❌       | ❌             |
# | 5.3           | ❌           | ❌           | ❌           | ❌       | ❌             |
# | 5.4           | ❌           | ❌           | ❌           | ❌       | ❌             |
# | 5.5           | ❌           | ❌           | ❌           | ❌       | ❌             |
# | 5.6           | ❌           | ✅           | ❌           | ❌       | ✅             |
# | 5.7           | ❌           | ✅           | ✅           | ❌       | ✅             |
# |----------------------------------------------------------------------------------------|
resolve_distribution_swift_version_matrix() {
    local variable_name=$1
    local requested_version=${!variable_name}
    local platform=$2
    local architecture=$3

    major="$(echo "${requested_version}" | grep -oE '^[0-9]+' || echo "0")"
    minor="$(echo "${requested_version}" | grep -oP '^[0-9]+\.\K[0-9]+' || echo "0")"
    breakfix="$(echo "${requested_version}" | grep -oP '^[0-9]+\.[0-9]+\.\K[0-9]+' 2>/dev/null || echo "0")"

    local identifier
    if [[ "${architecture}" == "aarch64" ]]; then
        identifier="${platform}-${architecture}"
    else
        identifier="${platform}"
    fi

    if [[ "${identifier}" == "centos7" ]]; then
        if [[ major -lt 6 ]] && [[ "${minor}" -lt 3 ]] && [[ "${breakfix}" -lt 5 ]]; then
            declare -g ${variable_name}="5.2.5"
            echo "Swift only officially supports CentOS 7 for Swift 5.2.5 and later. Using Swift 5.2.5 instead of "${requested_version}"."
        fi
    elif [[ "${identifier}" == "centos7-aarch64" ]]; then
        echo "aarch64 is not supported on ${PRETTY_NAME}. Try Ubuntu 20.04, 22.04, or Amazon Linux 2."
        exit 1
    elif [[ "${identifier}" == "amazonlinux2" ]]; then
        if [[ "${major}" -lt 6 ]] && [[ "${minor}" -lt 3 ]] && [[ "${breakfix}" -lt 4 ]]; then
            declare -g ${variable_name}="5.2.4"
            echo "Swift only officially supports Amazon Linux 2 for Swift 5.2.4 and later. Using Swift 5.2.4 instead of "${requested_version}"."
        fi
    elif [[ "${identifier}" == "amazonlinux2-aarch64" ]]; then
        if [[ "${major}" -lt 6 ]] && [[ "${minor}" -lt 6 ]]; then
            declare -g ${variable_name}="5.6"
            echo "Swift only officially supports the aarch64 architecture on Amazon Linux 2 for Swift 5.6 and later. Using Swift 5.6 instead of "${requested_version}"."
        fi
    elif [[ "${identifier}" == "ubuntu18.04-aarch64" ]]; then
        echo "aarch64 is not supported on ${PRETTY_NAME}. Try Ubuntu 20.04, 22.04, or Amazon Linux 2."
        exit 1
    elif [[ "${identifier}" == "ubuntu20.04" ]]; then
        if [[ "${major}" -lt 6 ]] && [[ "${minor}" -lt 3 ]] && [[ "${breakfix}" -lt 4 ]]; then
            declare -g ${variable_name}="5.2.4"
            echo "Swift only officially supports Ubuntu 20.04 for Swift 5.2.4 and later. Using Swift 5.2.4 instead of "${requested_version}"."
        fi
    elif [[ "${identifier}" == "ubuntu20.04-aarch64" ]]; then
        if [[ "${major}" -lt 6 ]] && [[ "${minor}" -lt 6 ]]; then
            declare -g ${variable_name}="5.6"
            echo "Swift only officially supports the aarch64 architecture on Ubuntu 20.04 for Swift 5.6 and later. Using Swift 5.6 instead of "${requested_version}"."
        fi
    elif [ "${identifier}" == "ubuntu22.04" ] || [ "${identifier}" == "ubuntu22.04-aarch64" ]; then
        if [[ "${major}" -lt 6 ]] && [[ "${minor}" -lt 7 ]]; then
            declare -g ${variable_name}="5.7"
            echo "Swift only officially supports Ubuntu 22.04 for Swift 5.7 and later. Using Swift 5.7 instead of "${requested_version}"."
        fi
    fi
}

apt_get_update() {
    if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
        echo "Running apt-get update..."
        apt-get -q update -y
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
        apt-get -q install -y --no-install-recommends "$@"
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
    export DEBCONF_NONINTERACTIVE_SEEN=true
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

find_version_from_git_tags SWIFT_VERSION "${platform}" "$(uname -m)" "https://github.com/apple/swift" "refs/tags/swift-"

# Install Swift
if [[ "${SWIFT_VERSION}" != "none" ]] && [[ "$(swift --version)" != *"${SWIFT_VERSION}"* ]]; then
    # pub   4096R/ED3D1561 2019-03-22 [SC] [expires: 2023-03-23]
    #       Key fingerprint = A62A E125 BBBF BB96 A6E0  42EC 925C C1CC ED3D 1561
    # uid                  Swift 5.x Release Signing Key <swift-infrastructure@swift.org
    swift_signing_key="A62AE125BBBFBB96A6E042EC925CC1CCED3D1561"
    swift_platform="${platform}"
    swift_branch="swift-${SWIFT_VERSION}-release"
    swift_version="swift-${SWIFT_VERSION}-RELEASE"
    swift_webroot="https://download.swift.org"

    set -e
    arch="$(uname -m)"
    if [[ "${arch}" == "aarch64" ]]; then
        os_arch_suffix="-aarch64"
    else 
        os_arch_suffix=""
    fi

    swift_webdir="${swift_webroot}/${swift_branch}/$(echo ${swift_platform} | tr -d .)${os_arch_suffix}"
    swift_bin_url="${swift_webdir}/${swift_version}/${swift_version}-${swift_platform}${os_arch_suffix}.tar.gz" \
    swift_sig_url="$swift_bin_url.sig" \
    # - Download the GPG keys, Swift toolchain, and toolchain signature, and verify.
    export GNUPGHOME="$(mktemp -d)"
    curl -fsSL "$swift_bin_url" -o swift.tar.gz "$swift_sig_url" -o swift.tar.gz.sig
    gpg --batch --quiet --keyserver keyserver.ubuntu.com --recv-keys "$swift_signing_key"
    gpg --batch --verify swift.tar.gz.sig swift.tar.gz || (echo "Failed to verify the GPG signature of ${swift_version}-${swift_platform}${os_arch_suffix}.tar.gz"; exit 1)
    # - Unpack the toolchain, set libs permissions, and clean up.
    tar -xzf swift.tar.gz --directory / --strip-components=1
    chmod -R o+r /usr/lib/swift
    rm -rf "$GNUPGHOME" swift.tar.gz.sig swift.tar.gz
    echo "$(swift --version)"
else
    echo "Swift is already installed with version ${SWIFT_VERSION}. Skipping."
fi

echo "Done!"