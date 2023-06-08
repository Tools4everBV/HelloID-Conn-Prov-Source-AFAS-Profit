| :information_source: Information |
|:---------------------------|
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.       |
<br />
<p align="center">
  <img src="https://www.tools4ever.nl/connector-logos/afas-logo.png">
</p>

## Versioning
| Version | Description | Date |
| - | - | - |
| 2.0.0   | Release of v2 connector including performance and logging upgrades | 2022/08/30  |
| 1.0.0   | Initial release | 2020/07/24  |

<!-- TABLE OF CONTENTS -->
## Table of Contents
- [Versioning](#versioning)
- [Table of Contents](#table-of-contents)
- [Introduction](#introduction)
- [Getting Started](#getting-started)
  - [Connection settings](#connection-settings)
  - [Prerequisites](#prerequisites)
  - [Source](#source)
  - [Remarks](#remarks)
  - [Mappings](#mappings)
  - [Scope](#scope)
  - [Target](#target)
- [Getting help](#getting-help)
- [HelloID docs](#helloid-docs)


## Introduction
The interface to communicate with Profit is through a set of GetConnectors, which is component that allows the creation of custom views on the Profit data. GetConnectors are based on a pre-defined 'data collection', which is an existing view based on the data inside the Profit database. 

For this connector we have created a default set, which can be imported directly into the AFAS Profit environment.

<!-- GETTING STARTED -->
## Getting Started

By using this connector you will have the ability to retrieve employee and contract data from the AFAS Profit HR system.

Connecting to Profit is done using the app connector system. 
Please see the following pages from the AFAS Knowledge Base for more information.

[Create the APP connector](https://help.afas.nl/help/NL/SE/App_Apps_Custom_Add.htm)

[Manage the APP connector](https://help.afas.nl/help/NL/SE/App_Apps_Custom_Maint.htm)

[Manual add a token to the APP connector](https://help.afas.nl/help/NL/SE/App_Apps_Custom_Tokens_Manual.htm)

### Connection settings

The following settings are required to connect to the API.

| Setting         | Description                                   | Mandatory   |
| --------------- | --------------------------------------------- | ----------- |
| BaseUrl         | The URL to the AFAS environment REST services | Yes         |
| ApiKey          | The AppConnector token to connect to AFAS     | Yes         |
| positionsAction | What to do with positions? Only use employments and skip positions (onlyEmployments) OR use positions and skip persons without (usePositions) | Yes         |

### Prerequisites

- [ ] HelloID Provisioning agent (cloud or on-prem).
- [ ] Loaded and available AFAS GetConnectors.
- [ ] AFAS App Connector with access to the GetConnectors and associated views.
  - [ ] Token for this AppConnector
  

### Source

The following GetConnectors are required by HelloID when the system is defined as source system: 

*	Tools4ever - HelloID - T4E_HelloID_Users_v2
*	Tools4ever - HelloID - T4E_HelloID_Employments_v2
*	Tools4ever - HelloID - T4E_HelloID_Positions_v2
*	Tools4ever - HelloID - T4E_HelloID_OrganizationalUnits_v2
*	Tools4ever - HelloID - T4E_HelloID_Groups_v2
*	Tools4ever - HelloID - T4E_HelloID_UserGroups_v2

### Remarks
 - In view of GDPR, the persons private data, such as private email address and birthdate are not in the data collection by default. When needed for the implementation (e.g. for person aggregation), these properties will have to be added.
 - This connector only supports the use of either employments or positions, not a combination of both! So when using positions, all employees are required to have positions. for more information, please see the AFAS [documentation](https://help.afas.nl/help/nl/se/Hrm_Config_OrgCht_Format.htm#o46970:~:text=van%20de%20functieregel.-,Ontbrekende%20formatieregels,-Als%20je%20de).

### Mappings
A basic mapping is provided. Make sure to further customize these accordingly.
Please choose the default mappingset to use with the configured configuration.

### Scope
The data collection retrieved by the set of GetConnector's is sufficient for HelloID to provision persons.
The data collection can be changed by the customer itself to meet their requirements.

| Connector                                             | Field               | Default filter            |
| ----------------------------------------------------- | ------------------- | ------------------------- |
| __Tools4ever - HelloID - T4E_HelloID_Users_v2__       | contract start date | <[Vandaag + 3 maanden]    |
|                                                       | contract end date   | >[Vandaag - 3 maanden];[] |
| __Tools4ever - HelloID - T4E_HelloID_Employments_v2__ | contract start date | <[Vandaag + 3 maanden]    |
|                                                       | contract end date   | >[Vandaag - 3 maanden];[] |
|                                                       | function start date | <[Vandaag + 3 maanden]    |
|                                                       | function end date   | >[Vandaag - 3 maanden];[] |
|                                                       | type of employee    | !=N                       |
| __Tools4ever - HelloID - T4E_HelloID_Positions_v2__   | function start date | <[Vandaag + 3 maanden]    |
|                                                       | function end date   | >[Vandaag - 3 maanden];[] |
|                                                       | type of employee    | !=N                       |
| __Tools4ever - HelloID - T4E_HelloID_Groups_v2__      | group               | !=iedereen                |
|                                                       | blocked             | =N                        |
| __Tools4ever - HelloID - T4E_HelloID_UserGroups_v2__  | group               | !=iedereen                |
|                                                       | user                | ![]                       |
|                                                       | blocked_group       | =N                        |
|                                                       | blocked_user        | =N                        |

### Target

When the connector is defined as target system, only the following GetConnector is used by HelloID:

*	Tools4ever - HelloID - T4E_HelloID_Users_v2

In addition to use to the above get-connector, the connector also uses the following build-in Profit update-connectors:

*	knPerson
*	knUser

## Getting help
> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/hc/en-us/articles/360012558020-Configure-a-custom-PowerShell-target-system) pages_

> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_

## HelloID docs
The official HelloID documentation can be found at: https://docs.helloid.com/
