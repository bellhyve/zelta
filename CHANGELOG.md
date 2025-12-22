# Changelog

All notable changes to the Zelta will be documented in this file.

## [1.1.beta1] - 2025-12-22
This section will be modified until v1.1 is officially released.

### Added
- **Commands**: `zelta revert` for in-place rollbacks via rename/clone.
- **Commands**: `zelta rotate` for divergent version handling, improved from original `--rotate`.
- **Core**: `zelta-args.awk` added as a separate argument preprocessor.
- **Core**: `zelta-common.awk` library for centralized string/logging functions.
- **Config**: Data-driven TSV configuration (`zelta-opts.tsv`, `zelta-cmds.tsv`).
- **Docs**: New `zelta-options(7)` manpage.

### Changed
- **Architecture**: Refactor of all core scripts for maintainability and simpler logic.
- **Core**: `bin/zelta` controller improved with centralized logging and better option handling.
- **Backup**: Rewritten `zelta backup` engine with improved state tracking and resume support.
- **Backup**: Core script renamed from `zelta-replicate.awk` to `zelta-backup.awk`.
- **Match**: `zelta match` now calls itself rather than a redundant script.
- **Match**: Output columns are now data driven with a simpler and clearer 'info' column.
- **Policy**: Better hierarchical scoping.
- **Orchestration**: Zelta is no longer required to be installed on endpoints.
- **Logging**: Better alerts, deprecation system, legacy option system, and warning messages.

### Deprecated
- `zelta endpoint` and other functions have been merged into the core library.
- Dropped unneeded interprocess communication features such as `sync_code` and `-z`.
- Removed "initiator" context which has been replaced by a simple `-pull` (default) and `--push` mechanic.
- Progress pipes (`RECEIVE_PREFIX`) now only work if the local host is involved in replication.

### Fixed
- Better handling of dataset names with spaces/special characters.
- Dataset type detection with environment variables for each (TOP, NEW, FS, VOL, RAW, etc.).
- Improved option hierarchy for `zelta policy`.

## [1.0.0] - 2024-03-31
- Initial public release for BSDCan 2024.
