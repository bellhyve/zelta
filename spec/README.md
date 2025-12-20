# Shellspec Testing
* * *
<!-- TOC -->
* [Shellspec Testing](#shellspec-testing)
  * [Overview](#overview)
    * [Installing ShellSpec](#installing-shellspec)
      * [🔰 Making your first test - a simple Example](#-making-your-first-test---a-simple-example)
  * [Testing `zelta`](#testing-zelta)
    * [:zap: To run the standard Zelta test](#zap-to-run-the-standard-zelta-test-)
    * [:zap: To run all tests](#zap-to-run-all-tests)
    * [🔰 shellspec examples](#-shellspec-examples)
<!-- TOC -->
* * * 
## Overview

[zelta](https://zelta.space/) uses [ShellSpec](https://github.com/shellspec/shellspec) for testing. If you're new to ShellSpec the
the following links are helpful:
- https://github.com/shellspec/shellspec
- https://shellspec.info/
- :star: https://deepwiki.com/shellspec/shellspec :heart:

### Installing ShellSpec

See the [ShellSpec installation guide](https://github.com/shellspec/shellspec#installation) for instructions.

#### 🔰 Making your first test - a simple Example
Use the hello_spec.sh file as a template for your first test.
- [hello_example.sh](./bin/hello_example.sh)
```shell
shellspec -f d spec/bin/hello_example.sh
```


### Verifying zfs configuation
```
# 1. Update package lists
sudo apt update

# 2. Install ZFS userspace tools
sudo apt install zfsutils-linux

# 3. Verify ZFS is installed and versions match
zfs version
cat /sys/module/zfs/version

# Expected output (both should match):
# zfs-2.2.2-0ubuntu9.4
# zfs-kmod-2.2.2-0ubuntu9.4
# or similar matching versions
```

## Setting up a local development environment
- [setup_local_dev_env.sh](./bin/setup_local_dev_env.sh)
<details>
<summary>Setting up an Ubuntu VM</summary>

This content is hidden by default and will be revealed when the user clicks on the summary.

</details>


## Testing `zelta`
> 🔑 zfs must be installed on your system.
>
> ℹ️ sudo is required because root privilege is needed for zfs and zelta commands
>
> ⛑️ Only temporary file backed zfs pools are used during testing
>
> 🦺 Install are local to a temporary directory
* * *
### :zap: To run the standard Zelta test 
[zelta_standard_test_spec.sh](./bin/zelta_standard_test_spec.sh) 
  ```
  sudo -E env "PATH=$PATH" shellspec -f d spec/bin/zelta_standard_test_spec.sh
  ```
  🔎 This test will create a standard setup via [initialize_testing_setup.sh](initialize/initialize_testing_setup.sh)
* * *    
### :zap: To run all tests
> ℹ️ Tests will run in the order they are listed in the spec directory
> use `-P, --pattern PATTERN` to filter tests by pattern
> the default pattern is `"*_spec.sh"`
```shell
sudo -E env "PATH=$PATH" shellspec -f d
```

* * *
### 🔰 shellspec examples
- Run all files matching a pattern [default: "*_spec.sh"]
`sudo -E env "PATH=$PATH" shellspec -f d -P "*_setup_*"`
- List all Groups (`Describe`) and Examples (`It`)
    ```shell
    # shellspec --list examples (directory/file)
    $ shellspec --list examples spec/bin
    spec/bin/zelta_standard_test_spec.sh:@1-1
    spec/bin/zelta_standard_test_spec.sh:@1-2
    spec/bin/zelta_standard_test_spec.sh:@2-1
    spec/bin/zelta_standard_test_spec.sh:@2-2
    ```
- Run all examples in group @1
    ```shell
    sudo -E env "PATH=$PATH" shellspec -f d spec/bin/zelta_standard_test_spec.sh:@1
    ```
- Run all examples 1 in group @1
    ```shell
    sudo -E env "PATH=$PATH" shellspec -f d spec/bin/zelta_standard_test_spec.sh:@1-1
    ```

