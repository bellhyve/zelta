#!/usr/bin/awk -f

# ignore blank lines
/^$/ { next }

# ignore comment lines starting with #
/^[[:space:]]*#/ { next }

# Process data lines
{
    gsub(/[[:space:]]+/, " ", $0)
    gsub(/@zelta_[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}\.[0-9]{2}\.[0-9]{2}/, "@zelta_\"*\"",$0)
    lines[count++] = $0
}

END {
    print func_name "() {"
    print "  while IFS= read -r line; do"
    print "    # normalize whitespace, remove leading/trailing spaces"
    print "    normalized=$(echo \"$line\" | tr -s '[:space:]' ' ' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    print "    case \"$normalized\" in"

    line_continue = "\"|\\"
    case_end = "\")"

    for (i = 0; i < count; i++) {
        line_end = (i + 1 == count) ? case_end : line_continue
        print "        \"" lines[i] line_end
    }

    print "        ;;"
    print "      *)"
    print "        printf \"Unexpected line format: %s\\n\" \"$line\" >&2"
    print "        return 1"
    print "        ;;"
    print "    esac"
    print "  done"
    print "  return 0"
    print "}"
}
