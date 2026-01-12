## Utilities

`match_function_generator.sh` - create case statement for shellspec 

## Examples

### Shellspec matcher example 
- ### Generating a matcher function or shellspec from zelta match output
```shell
$ ./matcher_func_generator.sh test_data/zelta_match_output.txt match_after_rotate_output
match_after_rotate_output() {
  while IFS= read -r line; do
    # normalize whitespace, remove leading/trailing spaces
    normalized=$(echo "$line" | tr -s '[:space:]' ' ' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    case "$normalized" in
        "DS_SUFFIX MATCH SRC_LAST TGT_LAST INFO"|\
        "[treetop] @zelta_"*" @zelta_"*" @zelta_"*" up-to-date"|\
        "/sub1 @zelta_"*" @zelta_"*" @zelta_"*" up-to-date"|\
        "/sub1/child @zelta_"*" @zelta_"*" @zelta_"*" up-to-date"|\
        "/sub2 @two @zelta_"*" @two syncable (incremental)"|\
        "/sub2/orphan @two @zelta_"*" @two syncable (incremental)"|\
        "/sub3 @two @zelta_"*" @two syncable (incremental)"|\
        "/sub3/space name @two @zelta_"*" @two syncable (incremental)"|\
        "/vol1 @go @zelta_"*" @go syncable (incremental)"|\
        "3 up-to-date, 5 syncable"|\
        "8 total datasets compared")
        ;;
      *)
        printf "Unexpected line format: %s\n" "$line" >&2
        return 1
        ;;
    esac
  done
  return 0
}
```

- ### Shellspec example using the generated matcher
```shell
Describe 'test zelta match output example'
    It "match $SOURCE and $TARGET"
       When call zelta match $SOURCE $TARGET
       The output should satisfy match_after_rotate_output
       The status should equal 0
    End
Enc
```