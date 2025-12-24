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
