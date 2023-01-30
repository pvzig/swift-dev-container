
## OS Support

This Feature works on all of the following officially supported distributions:
- Ubuntu 18.04
- Ubuntu 20.04
- Ubuntu 22.04
- CentOS 7
- Amazon Linux 2

and is unsupported but may work on the following distributions:
- Debian 10
- Debian 11

Certain versions of Swift are only supported on certain distributions (see matrix below). The `install.sh` script will do it's best to match the host distro with the closest supported version of Swift.

## x86
| Swift Version | Ubuntu 18.04 | Ubuntu 20.04 | Ubuntu 22.04 | CentOS 7 | Amazon Linux 2 |
|---------------|--------------|--------------|--------------|----------|----------------|
| 5.0           | ✅           | ❌           | ❌           | ❌       | ❌             |
| 5.1           | ✅           | ❌           | ❌           | ❌       | ❌             |
| 5.2           | ✅           | ❌           | ❌           | ❌       | ❌             |
| 5.2.4         | ✅           | ✅           | ❌           | ❌       | ✅             |
| 5.2.5         | ✅           | ✅           | ❌           | ✅       | ✅             |
| 5.3           | ✅           | ✅           | ❌           | ✅       | ✅             |
| 5.4           | ✅           | ✅           | ❌           | ✅       | ✅             |
| 5.5           | ✅           | ✅           | ❌           | ✅       | ✅             |
| 5.6           | ✅           | ✅           | ❌           | ✅       | ✅             |
| 5.7           | ✅           | ✅           | ✅           | ✅       | ✅             |

## aarch64
| Swift Version | Ubuntu 18.04 | Ubuntu 20.04 | Ubuntu 22.04 | CentOS 7 | Amazon Linux 2 |
|---------------|--------------|--------------|--------------|----------|----------------|
| 5.0           | ❌           | ❌           | ❌           | ❌       | ❌             |
| 5.1           | ❌           | ❌           | ❌           | ❌       | ❌             |
| 5.2           | ❌           | ❌           | ❌           | ❌       | ❌             |
| 5.2.4         | ❌           | ❌           | ❌           | ❌       | ❌             |
| 5.2.5         | ❌           | ❌           | ❌           | ❌       | ❌             |
| 5.3           | ❌           | ❌           | ❌           | ❌       | ❌             |
| 5.4           | ❌           | ❌           | ❌           | ❌       | ❌             |
| 5.5           | ❌           | ❌           | ❌           | ❌       | ❌             |
| 5.6           | ❌           | ✅           | ❌           | ❌       | ✅             |
| 5.7           | ❌           | ✅           | ✅           | ❌       | ✅             |

`bash` is required to execute the `install.sh` script.
