# Zelta Style Guide & Coding Standards

This document defines the coding standards for the Zelta Backup and Recovery Suite. Zelta is designed for **portability** and **safety** and is written in portable Bourne Shell and Awk.

A good rule of thumb is to lean towards POSIX and "Original Awk" standards. However, to be portable with most systems that have ever run OpenZFS, we can't adhere obsessively to not to a specific standard or ideal. For example, some POSIX standards are absent from some operating system defaults and everything needs to be tested.

---

## 1. Naming Conventions

We use specific casing to denote variable scope and type.

| Type | Case Style | Example | Context |
| :--- | :--- | :--- | :--- |
| **Constants** | CAPS | `SNAP_NAME` | Values that do not change during runtime. |
| **Globals** | CamelCase | `Dataset`, `NumDS` | Global state variables, available throughout execution. |
| **Locals** | _snake_case | `_idx`, `_temp_val` | specific variables internal to a function or loop. |
| **Arguments** | lowercase | `target_ds`, `flag` | Variables passed into a function. |
| **Array Keys (Const)** | "CAPS" | `Opt["VERBOSE"]` | Settings or fixed keys within associative arrays. |
| **Array Keys (Local)** | "lowercase" | `Dataset[ds_suffix, "match"]` | Keys that are applied during script runtime. |

---

## 2. Core Concepts & Vocabulary

Though we follow OpenZFS's language concepts when possible, some terms aren't clearly defined in the OpenZFS project documentation.

*   **endpoint (ep):** The location and name of a ZFS object.
*   **dataset (ds):** A specific individual ZFS dataset.
*   **tree:** A dataset and its recursive children.
*   **dataset tree:** The preferred term when describing recursive operations on a dataset and all its descendants.
*   **ds_snap:** A specific snapshot instance (e.g., `pool/data@snap1`).
*   **ds_suffix:** The relative path of a child element within a tree with a leading `/` (formerly referred to as `rel_name`).
    *   *Example:* If root is `zroot/usr`, and we process `zroot/usr/local`, the `ds_suffix` is `/local`.

---

## 3. Data Structures

Global state is managed via multidimensional associative arrays in AWK.

### `Opt[]`
**User Settings.**
Defined definitions in `zelta` sh script and parsing rules in `zelta-opts.tsv`.
*   Index: `Opt["VARIABLE_NAME"]`

### `Dataset[]`
**Properties of each dataset.**
Indexed by Endpoint, the Suffix, and the Property Name.
*   **Index:** `(endpoint, ds_suffix, property)`
*   **Standard Properties:**
    *   `"exists"`: (Boolean) Does it exist?
    *   `"earliest_snapshot"`: The oldest snapshot on the system.
    *   `"latest_snapshot"`: The newest snapshot.
    *   `[zfs_property]`: Any native ZFS property (e.g., `"compression"`, `"origin"`), sourced via `zelta-match`.

### `DSPair[]`
**Derived Replication State.**
Compares a dataset and its replica counterpart.
*   **Index:** `(ds_suffix, property)`
*   **Standard Properties:**
    *   `"match"`: The common snapshot or bookmark shared between Source and Target.
    *   `"source_start"`: The incremental source snapshot/bookmark used as the send basis.
    *   `"source_end"`: The target snapshot intended to be synced.

### `DSTree[]`
**Global Tree Metadata.**
*   **Index:** `(property)` or `(endpoint, property)`
*   **Standard Properties:**
    *   `"SRC", "count"`: Number of datasets on source.
    *   `"TGT", "count"`: Number of datasets on target.

### Global Scalars
*   `NumDS`: Integer count of datasets in the current tree.
*   `DSList`: An ordered list (often space-separated or indexed array) of `ds_suffix` elements in replication order.

---

## 4. Coding Standards

### Bourne Shell (`/bin/sh`)
*   **Shebang:** `#!/bin/sh`
*   **No Bashisms:** No arrays (`arr=(...)`), no `[[ ]]`, no `function name() {`. Use `name() {`.
*   **Variables:** Quote all variables unless tokenization is explicitly desired.
*   **Indentation:** Use **Tabs** for block indentation. Use **Spaces** for inline alignment of comments or assignments.

### AWK (`awk`)
*   **Dialect:** Original-Awk (bwk/nawk) styled, code must run on stock FreeBSD, Illumos, and Debian `awk`.
*   **Indentation:** Same as Shell (Tabs for structure, Spaces for alignment).

### Portability
*   Assume the environment is hostile.
*   Assume `grep` logic varies.
*   Do not assume GNU or BSD extensions are present.

---

## 5. Comments & Documentation

Good comments explain **why** and **what**, not just **how**. They should help future maintainers understand the intent and context.

### Comment Styles

| Style | Usage | Example |
| :--- | :--- | :--- |
| `##` | **Section Headers** | `## Loading and setting properties` |
| `#` | **Function Headers** | `# Evaluate properties needed for snapshot decision` |
| `#` | **Inline Explanations** | `_idx = endpoint SUBSEP ds_suffix  # Build array key` |
| `# TO-DO:` | **Future Work** | `# TO-DO: This should be its own function` |

### What to Comment

*   **Complex Array Indexing:** Explain multi-dimensional array structures.
    ```awk
    # Dataset properties indexed by: (endpoint, ds_suffix, property)
    Dataset[_idx, "latest_snapshot"] = snap_name
    ```

*   **Business Logic:** Explain the reasoning behind complex conditionals.
    ```awk
    # If this is the first snapshot for the source, update the snap counter
    if (!_src_latest)
        Dataset[_idx, "earliest_snapshot"] = snap_name
    ```

*   **State Changes:** Document when and why global state is modified.
    ```awk
    # The target is updated via a sync and becomes our new match
    DSPair[ds_suffix, "match"] = snap_name
    ```

*   **External Dependencies:** Explain interactions with external commands.
    ```awk
    # Run 'zfs match' and pass to parser
    _cmd = build_command("MATCH", _cmd_arr)
    ```

### What NOT to Comment

*   **Obvious Operations:** Don't comment simple assignments or standard patterns.
*   **Redundant Descriptions:** Avoid comments that just restate the code.

### Section Organization

Use `##` headers to create logical code sections:
```awk
## Usage
########

## Loading and setting properties  
#################################

## Compute derived data from properties and snapshots
#####################################################
```

---

## 6. Documentation Standards

Zelta documentation serves different audiences with different needs. Maintain appropriate tone and style for each context.

### Documentation Hierarchy

| Document Type | Audience | Tone | Purpose |
| :--- | :--- | :--- | :--- |
| **Man Pages** | Sysadmins at 4am | Strictly technical, no personality | Complete reference, troubleshooting |
| **README.md** | Evaluators, new users | Professional but approachable | "What" and "why", getting started |
| **Wiki Pages** | Community, learners | Conversational, tutorial-focused | How-to guides, examples, discussion |
| **Code Comments** | Developers, maintainers | Technical, explanatory | Intent and context |

### Man Page Standards

Man pages are reference documentation. They must be:

*   **Complete:** Cover all options, arguments, and behaviors
*   **Precise:** Use exact terminology consistently
*   **Scannable:** Use clear headers, tables, and formatting
*   **Example-driven:** Show common use cases with realistic examples

**Man Page Structure:**
```
NAME - Brief description
SYNOPSIS - Command syntax
DESCRIPTION - What it does and how
OPTIONS - All flags and arguments
EXAMPLES - Common use cases
EXIT STATUS - Return codes
NOTES - Important caveats
SEE ALSO - Related commands
AUTHORS - Credit
WWW - Project URL
```

**Man Page Formatting:**
*   Use `**bold**` for commands, options, and user input
*   Use `*italic*` for arguments and placeholders
*   Use `:` for definition lists
*   Escape dashes in options: `**\--verbose**`
*   Use tables for complex option lists

### README.md Standards

The README serves as the project's front door. It should be:

*   **Welcoming:** Professional tone, avoid jargon where possible
*   **Focused:** Lead with value proposition and quickstart
*   **Honest:** State limitations and beta status clearly
*   **Actionable:** Clear next steps for different user types

**Avoid in README.md:**
*   Marketing hyperbole ("revolutionary", "game-changing")
*   Antagonistic comparisons ("unlike X which is terrible")
*   Excessive casualness ("no bull", "ridiculously simple")
*   Unsubstantiated claims

**Prefer in README.md:**
*   Concrete examples with realistic scenarios
*   Factual statements about capabilities
*   Clear, direct language ("simple", "straightforward")
*   Specific technical advantages

### Terminology Consistency

Use these terms consistently across all documentation:

| Preferred | Avoid | Context |
| :--- | :--- | :--- |
| dataset tree | recursive datasets | When describing parent + children |
| endpoint | location, target system | For `user@host:pool/dataset` |
| replication | backup, sync | For `zelta backup` operations |
| snapshot | snap | Except in code/options |

### Example Formatting

**Endpoint Examples:**
Always use realistic, complete examples:
*   Good: `user@backup.example.com:tank/backups/dataset`
*   Avoid: `host:pool/ds`, `remote:tank/backup`

**Command Examples:**
Show complete, working commands:
```sh
# Good: Complete with context
zelta backup rpool/data backup@storage.example.com:tank/backups/data

# Avoid: Incomplete or unclear
zelta backup source target
```

### Writing Style Guidelines

**Do:**
*   Use active voice ("Zelta creates snapshots" not "Snapshots are created")
*   Start with the most common use case
*   Explain *why* before *how* when introducing concepts
*   Use parallel structure in lists
*   Define acronyms on first use

**Don't:**
*   Use exclamation points in technical documentation
*   Make unverifiable claims
*   Use marketing language in man pages
*   Assume prior knowledge of ZFS internals
*   Mix casual and formal tone in the same document

### Cross-Reference Standards

When referencing other documentation:

*   Man pages: Use standard notation `**command(section)**` (e.g., `**zfs(8)**`)
*   Internal docs: Use relative links in markdown
*   External docs: Use full URLs with descriptive text
*   Be specific: "See the EXCLUSION PATTERNS section in **zelta-options(7)**" not "See zelta-options"

### Consistency Checklist

Before committing documentation changes, verify:

- [ ] Terminology matches STYLE.md vocabulary
- [ ] Tone appropriate for document type
- [ ] Examples use realistic hostnames (*.example.com)
- [ ] Command formatting consistent (escaped dashes in man pages)
- [ ] Cross-references use correct notation
- [ ] No marketing language in technical docs
- [ ] Tables formatted consistently
- [ ] Code blocks use appropriate syntax highlighting
