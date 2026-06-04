# Shellspec Command Line Filtering Options

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
