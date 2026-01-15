# Shellspec Testing
* * *
<!-- TOC -->
* [Shellspec Testing](#shellspec-testing)
  * [Overview](#overview)
    * [Installing ShellSpec](#installing-shellspec)
      * [🔰 Making your first test - a simple Example](#-making-your-first-test---a-simple-example)
    * [Setting up a local development environment](#setting-up-a-local-development-environment)
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
- The following works on FreeBSD and Ubuntu
- `curl -fsSL https://git.io/shellspec | sh`
- Add `$HOME/.local/bin` to your `PATH`

#### 🔰 Making your first test - a simple Example
Use the hello_spec.sh file as a template for your first test.
- [hello_example.sh](./bin/hello_example.sh)
```shell
shellspec -f d spec/bin/hello_example.sh
```

### Setting up a local development environment
- [Ubuntu VM](./doc/vm/README.md)


## Testing `zelta`
> 🔑 zfs must be installed on your system.
>
> ℹ️ sudo is required because root privilege is needed for zfs and zelta commands
>
> ⛑️ Only temporary file backed zfs pools are used during testing
>
> 🦺 Installs are local to a temporary directory
* * *
### :star: Using the test helper
```shell
% ~/src/repos/zelta$ test/test_runner.sh
Error: Expected 2 arguments: <target> <tree_name>
Usage: test/test_runner.sh <local|remote> <standard|divergent|encrypted>
```
- For remote tests setup your server and backup user
- Export the following env vars before running
```shell
# for example
# TODO: use the same server, multiple servers is a WIP
# NOTE: different servers for SRC and TGT is a WIP 
export SRC_SVR="backupuser@server"
export TGT_SVR="backupuser@server"
```

- Typical test secnarios for local testing
  - TODO: encrypted trees aren't implemented yet
``` 
test/test_runner.sh local standard
test/test_runner.sh local divergent
test/test_runner.sh remote standard
test/test_runner.sh remote divergent
```

### Example test_runner.sh output
- Recommendation: test locally first, before trying remote

<details>

<summary>remote standard run</summary>

```shell
% test/test_runner.sh remote standard

# setup output omitted
# respond to install prompt and sudo password for pool setup
 _____    _ _          _____         _
|__  /___| | |_ __ _  |_   _|__  ___| |_
  / // _ \ | __/ _` |   | |/ _ \/ __| __|
 / /|  __/ | || (_| |   | |  __/\__ \ |_
/____\___|_|\__\__,_|   |_|\___||___/\__|

[info] specshell precheck: version:0.28.1 shell: sh 
[info] *** TREE_NAME    is {standard}
[info] *** RUNNING_MODE is {remote}
[info] ***
[info] *** Running Remotely
[info] *** Source Server is SRC_SVR:{dever@fzfsdev}
[info] *** Target Server is TGT_SVR:{dever@fzfsdev}
[info] ***
Settings OS specific environment for {Linux}
OS_TYPE: Linux: set POOL_TYPE={2}
Running: /bin/sh [sh]

confirm zfs setup
  has good initial SRC_POOL:{apool} simple snap tree
  has good initial TGT_POOL:{bpool} simple snap tree
try backup
  backs up the initial tree
  has valid backup
  has 8 snapshots on dever@fzfsdev matching pattern '^(apool|bpool)'
  has 4 snapshots on dever@fzfsdev matching pattern 'apool/treetop'
  has 4 snapshots on dever@fzfsdev matching pattern 'bpool/backups/treetop'
zelta rotate
  rotates the backed up tree
  has 16 snapshots on dever@fzfsdev matching pattern '^(apool|bpool)'
  has 8 snapshots on dever@fzfsdev matching pattern 'apool/treetop'
  has 8 snapshots on dever@fzfsdev matching pattern 'bpool/backups/treetop'

Finished in 7.30 seconds (user 1.60 seconds, sys 0.12 seconds)
11 examples, 0 failures


✓ Tests complete

```

</details>


<details>

<summary>remote divergent run </summary>

```shell
% test/test_runner.sh remote divergent

# setup output omitted
# respond to install prompt and sudo password for pool setup

 _____    _ _          _____         _
|__  /___| | |_ __ _  |_   _|__  ___| |_
  / // _ \ | __/ _` |   | |/ _ \/ __| __|
 / /|  __/ | || (_| |   | |  __/\__ \ |_
/____\___|_|\__\__,_|   |_|\___||___/\__|

[info] specshell precheck: version:0.28.1 shell: sh 
[info] *** TREE_NAME    is {divergent}
[info] *** RUNNING_MODE is {remote}
[info] ***
[info] *** Running Remotely
[info] *** Source Server is SRC_SVR:{dever@fzfsdev}
[info] *** Target Server is TGT_SVR:{dever@fzfsdev}
[info] ***
Settings OS specific environment for {Linux}
OS_TYPE: Linux: set POOL_TYPE={2}
Running: /bin/sh [sh]

confirm zfs setup
  zfs list output validation
    matches expected pattern for each line
  check initial zelta match state
    initial match has 5 up-to-date, 1 syncable, 3 blocked, with 9 total datasets compared
  add incremental source snapshot
    adds dever@fzfsdev:apool/treetop/sub3@two snapshot
  add divergent snapshots of same name
    adds divergent snapshots for dever@fzfsdev:apool/treetop/sub2@two and dever@fzfsdev:bpool/backups/treetop/sub2@two
  check zelta match after divergent snapshots
    after divergent snapshot match has 2 up-to-date, 2 syncable, 5 blocked, with 9 total datasets compared
Divergent match, rotate, match
  shows current match for divergent dever@fzfsdev:apool/treetop and dever@fzfsdev:bpool/backups/treetop
  rotate divergent dever@fzfsdev:apool/treetop and dever@fzfsdev:bpool/backups/treetop
  match dever@fzfsdev:apool/treetop and dever@fzfsdev:bpool/backups/treetop after divergent rotate
Divergent backup, then match
  backup divergent dever@fzfsdev:apool/treetop to dever@fzfsdev:bpool/backups/treetop
  match after backup

Finished in 7.95 seconds (user 2.09 seconds, sys 0.22 seconds)
10 examples, 0 failures


✓ Tests complete
```

</details>

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
- `:@1` 🟰 Run all examples in group @1
    ```shell
    sudo -E env "PATH=$PATH" shellspec -f d spec/bin/zelta_standard_test_spec.sh:@1
    ```
- `:@-1` 🟰 Run only example #1 in group @1
    ```shell
    sudo -E env "PATH=$PATH" shellspec -f d spec/bin/zelta_standard_test_spec.sh:@1-1
    ```
- use options `--xtrace --shell bash` to show a trace with expectation evaluation
  ```shell
  shellspec -f d --xtrace --shell bash spec/bin/standard_test/standard_test_spec.sh:@2-2  
  ```
