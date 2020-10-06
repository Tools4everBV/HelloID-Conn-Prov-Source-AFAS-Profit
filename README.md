# HelloID-Conn-Prov-Source-AFAS-Profit
<p align="center">
  <img src="https://user-images.githubusercontent.com/68013812/94159371-c1928f80-fe83-11ea-9582-1e4504da8282.png">
</p>

<!-- TABLE OF CONTENTS -->
## Table of Contents
* [Introduction](#introduction)
* [Getting Started](#getting-started)
  * [Source](#source)
  * [Target](#target)
  * [Scope](#scope)
* [Usage](#usage)


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


### Source

The following GetConnectors are required by HelloID when the system is defined as source system: 

*	Tools4ever - HelloID - T4E_HelloID_Employments
*	Tools4ever - HelloID - T4E_HelloID_Groups
*	Tools4ever - HelloID - T4E_HelloID_OrganizationalUnits
*	Tools4ever - HelloID - T4E_HelloID_Users
*	Tools4ever - HelloID - T4E_HelloID_UserGroups

### Target

When the connector is defined as target system, only the following GetConnector is used by HelloID:

*	Tools4ever - HelloID - T4E_HelloID_Users

In addition to use to the above get-connector, the connector also uses the following build-in Profit update-connectors:

*	knEmployee
*	knUser

### Scope

The data collection retrieved by the set of GetConnector's used in this repository is limited a maximum amount of data, these limits are set as pre-defined filters and can be changed by the customer itself to meet their requirements.

<table>
<tr><td><b>Connector</b></td><td><b>Field</b></td><td><b>Default filter</b></td></tr>
<tr><td><i><b>Tools4ever - HelloID - T4E_HelloID_Employments</b></i></td><td>contract start date</td><td>&lt;[Vandaag + 1 maand]</td></tr>
<tr><td>&nbsp;</td><td>contract end date</td><td>&gt;[Vandaag - 3 maanden];[]</td></tr>
<tr><td>&nbsp;</td><td>function start date</td><td>&lt;[Vandaag + 1 maand]</td></tr>
<tr><td>&nbsp;</td><td>function end date</td><td>&gt;[Vandaag - 3 maanden];[]</td></tr>
<tr><td><i><b>Tools4ever - HelloID - T4E_HelloID_Groups</b></i></td><td>usergroup blocked</td><td>=N</td></tr>
<tr><td><i><b>Tools4ever - HelloID - T4E_HelloID_UserGroups</b></i></td><td>Group</td><td>!=Iedereen</td></tr>
<tr><td>&nbsp;</td><td>User</td><td>![]</td></tr>
<tr><td>&nbsp;</td><td>user blocked</td><td>=N</td></tr>
<tr><td>&nbsp;</td><td>usergroup blocked</td><td>=N</td></tr>
<tr><td><i><b>Tools4ever - HelloID - T4E_HelloID_Users</b></i></td><td>contract start date</td><td>&lt;[Vandaag + 1 maand]</td></tr>
<tr><td>&nbsp;</td><td>contract end date</td><td>&gt;[Vandaag - 3 maanden];[]</td></tr>
<tr><td>&nbsp;</td><td>user blocked</td><td>=N</td></tr>
</table>


<!-- USAGE EXAMPLES -->
## Usage

_For more information about our HelloID PowerShell connectors, please refer to our general [Documentation](https://docs.helloid.com/hc/en-us/articles/360012558020-How-to-configure-a-custom-PowerShell-target-connector) page_