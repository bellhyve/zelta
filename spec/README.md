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
- [hello_example.sh](./bin/hello_example.sh)
```shell
shellspec -f d spec/bin/hello_example.sh
```

## Testing `zelta`
To configure your environment for zelta testing, run the following command.

> [!NOTE]
> zfs must be installed on your system.

> [!WARNING]
> The command requires root privileges because is sets up zfs file backed pools. 


### To setup a zelta standard test 
- [zelta_standard_test_spec.sh](./bin/zelta_standard_test_spec.sh)
NOTE: this test will create a standard setup via [initialize_testing_setup.sh](initialize/initialize_testing_setup.sh) 
    ```shell
    sudo -E env "PATH=$PATH" shellspec -f d spec/bin/zelta_standard_test_spec.sh
    ```

### To run all tests
> [!NOTE] 
> tests will run in the order they are listed in the spec directory
> use -P, --pattern PATTERN to filter tests by pattern
> the default pattern is "*_spec.sh"
```shell
sudo -E env "PATH=$PATH" shellspec -f d
```


### shellspec examples
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

