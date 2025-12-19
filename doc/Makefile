# Create manpages. If installed for a particular user, these can be used
# with `zelta help` by setting the path via ZELTA_MAN, e.g.,
# `export ZELTA_MAN="${HOME}/.config/zelta/doc"`

.SUFFIXES: .md .8

MAN_PAGES = $(patsubst %.md,%.8,$(wildcard *.md))

all: $(MAN_PAGES)

.md.8:
	pandoc --standalone --to man $< -o $@

clean:
	rm -f $(MAN_PAGES)

.PHONY: all clean
