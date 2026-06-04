# Test Generation

Maintaining test correctness between versions of zelta is simplified by automatically 
generating the test files from a YAML definition file.

## Generate all tests
```shell
./generate_all_tests.sh
```

## Generating s specific test
```shell
./generate_test.sh (test-def-yml) (prod-location) (shellspec-setup)
```
### where:
- `test-def-yml`: YAML file defining the test located in `../config/test_defs`
- `prod-location`: on successful generation, move generated spec file to this directory
- `shellspec-setup`: shellspec setup instructions
   - shellspec-setup: `[options=value] (pattern=value|tag=value|path=value)...`   
      - `options=value`: defines `$options` for each shellspec invocation
      - `pattern=value`: invokes `shellspec $options --pattern "$value"`
      - `tag=value`:     invokes `shellspec $options --tag "$value"`
      - `path=value`:    invokes `shellspec $options "$value"`

### examples:
- review `generate_*_*_test.sh` scripts for examples

- - - 
# Shellspec Command Line Filtering Options 
> included from shellspec documentation for convenience 
## Line Numbers and IDs
```shell
shellspec path/to/a_spec.sh:10      # Run groups/examples that include line 10  
shellspec path/to/a_spec.sh:@1-5    # Run the 5th example in the 1st group  
shellspec a_spec.sh:10:@1:20:@2     # Mix multiple line numbers and IDs
```

## Pattern Filtering

File pattern: `-P, --pattern PATTERN` - Load files matching pattern (default: *_spec.sh) parser_definition.sh:206-207

Example pattern: `-E, --example PATTERN` - Run examples whose names include PATTERN parser_definition.sh:209-210

## Tag Filtering
Use -T, --tag TAG[:VALUE] to run examples with specified tags parser_definition.sh:212-213 :

```shell
shellspec --tag slow  
shellspec --tag tagA:val1,tagA:val2
```

## Path Filtering

Specify paths recursively with special prefixes (requires quotes)

```shell
shellspec "*/spec"               # Pattern "*/" matches 1 directory  
shellspec "**/spec"              # Pattern "**/" matches 0+ directories  
shellspec "*/*/**/test_spec.sh"  # Multiple patterns can be combined
```

## Focus Mode
Use the -F, --focus flag to run only focused groups/examples (those prefixed with f in the DSL) parser_definition.sh:203-204 :
```shell
shellspec --focus
```
