# Change Log

All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com), and this project adheres to [Semantic Versioning](https://semver.org).

## [2.2.1] - 2025-12-19

### Added
- New configuration option `excludePersonsWithoutContractsInHelloID` (default: true) that controls whether persons without contracts are excluded from the export
  - Replaces the previously commented-out logic that required manual code changes
  - When enabled, persons with no contracts or empty contract arrays are automatically excluded from HelloID
  - Provides configurable control over which persons are synchronized to HelloID

### Removed
- Commented-out code blocks that previously required manual consultant intervention to enable/disable contract filtering

## [2.2.0] - 2025-08-08

### Changed
- Various connector improvements and updates

## [2.1.1] - 2024-05-06

### Changed
- Commented out example code that should not run by default

## [2.1.0] - 2024-05-06

### Added
- Added commented-out example to add boolean value if person is manager

## [2.0.2] - 2024-01-16

### Fixed
- Corrected mapping where complex mapping uses functions

## [2.0.1] - 2023-08-22

### Changed
- General updates and improvements

## [2.0.0] - 2023-08-21

This release includes significant performance and logging improvements for the AFAS Profit connector.

### Added
- Updated GetConnectors to Profit 1 versions

### Changed
- Performance upgrades to improve connector efficiency
- Enhanced logging capabilities for better troubleshooting and monitoring
- Changed output to only contain data HelloID uses
- Added sorting to API calls
- Improved and simplified logging

### Fixed
- Various bug fixes and improvements

## [1.0.0] - 2023-06-19

This is the first official release of _HelloID-Conn-Prov-Source-AFAS-Profit_.

### Added
- Initial implementation of AFAS Profit source connector
- Support for retrieving employee and contract data from AFAS Profit HR system
- App connector integration for secure communication with AFAS Profit
- Custom GetConnectors for data retrieval
- Person and department data synchronization
- Contract and position mapping capabilities
- Manager ExternalId support
- Integration Id to requests
