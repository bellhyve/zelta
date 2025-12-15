# Shellspec Testing
* * *
<!-- TOC -->
* [Shellspec Testing](#shellspec-testing)
  * [Overview](#overview)
    * [Installing ShellSpec](#installing-shellspec)
    * [Making your first test - a simple Example](#making-your-first-test---a-simple-example)
  * [Testing `zelta`](#testing-zelta)
<!-- TOC -->

* * * 
## Overview

[zelta](https://zelta.space/) uses [ShellSpec](https://github.com/shellspec/shellspec) for testing. If you're new to ShellSpec the
the following links are helpful:
- https://github.com/shellspec/shellspec
- https://shellspec.info/
> [!NOTE]
> :star: https://deepwiki.com/shellspec/shellspec

### Installing ShellSpec

See the [ShellSpec installation guide](https://github.com/shellspec/shellspec#installation) for instructions.


### Making your first test - a simple Example
Use the hello_spec.sh file as a template for your first test.
- [hello_spec.sh](./bin/hello_spec.sh)
```shell
shellspec -f d spec/bin/hello_spec.sh
```

## Testing `zelta`
To configure your environment for zelta testing, run the following command.

> [!NOTE]
> zfs must be installed on your system.

> [!WARNING]
> The command requires root privileges because is sets up zfs file backed pools. 


### To setup a zelta test environment 
- [zelta_test_setup_spec.sh](./bin/zelta_test_setup_spec.sh)
    ```shell
    sudo -E env "PATH=$PATH" shellspec -f d spec/bin/zelta_test_setup_spec.sh
    ```

### To run all tests
> [!NOTE]
> We are using naming convention for tests to run them in a specific order. 
> Name your new tests staring with the highest existing test number + 1.
> **This strategy is subject to change and is a WIP** 

```shell
sudo -E env "PATH=$PATH" shellspec -f d
```