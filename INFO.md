# AFAS

Connect HelloID to AFAS for the same reason your organization implemented an HR solution: automation. AFAS Software provides solutions for automating tedious HR, finance, and payroll administration. AFAS Software also provides the AFAS Pocket app for accessing HR and ERP systems while on-the-go.

By connecting AFAS’s solutions to HelloID, you have the perfect foundation of data to fully automate your organization’s identity management. HelloID provides an attribute mapper to sync with AFAS. The attribute mapper’s configuration links identity data from AFAS fields and variables to HelloID.

Tools4ever is a certified partner of AFAS.

## Onboarding, Provisioning, & Ongoing Management

HR remains responsible for adding and updating information in AFAS. HelloID detects changes in the HR system via the connector. Detected changes trigger processes that update users and their access to connected IT resources according to your configurations. Processes are automatic, consistent, and logged—reclaiming significant IT staff bandwidth.

For new users entered into AFAS, HelloID automatically provisions accounts, group memberships, and permissions. HelloID processes changes made to existing users in the HR system to ensures everything remains up-to-date. When an employee departs, HR changes their status in AFAS and HelloID automatically executes all configured offboarding processes.

By leveraging AFAS’ data for every employee, automated attribute-based access control has never been as quick or easy.

### HelloID Provisioning Examples with AFAS

| Change in AFAS | In-network Procedure (Automated by HelloID) |
| :-- | :-- |
| **New employee** | Based on information in AFAS, a user account is created with the configured group memberships according to the employee’s role. Typically, this occurs in (Azure) AD. User accounts and rights are also created in downstream systems. Tools4ever has more than 150 links with various target systems. |
| **Employee Position/Role Change** | The supplied authorization model in HelloID is automatically consulted for the new role’s permissions. Accounts and rights are added and removed accordingly. |
| **Employee Departure** | User accounts are dismantled in phases, and relevant parties are informed. |
| **Employee Marriage/Divorce** | The display name and e-mail address are adjusted (if desired). |
| **Employee Location Change** | Home directory data is moved to the nearest home directory server. |

### Service Automation for User Self-Service

Outside of standard provisioning configurations, users may access HelloID’s Service Automation module to request access to additional resources from their dashboard. If approved by the associated “Product Owner,” HelloID processes all changes and provisioning needs.

With HelloID connected to AFAS, “Product Owners” may be assigned based on their attributes synced from the HR System. Examples of these attributes would be position or contract data that specifies department heads, managers, or team leaders.

## Access Management: Single Sign-On (SSO) with AFAS Pocket

AFAS Pocket is an app for your employees with a broad range of self-service functionality for submitting PTO requests, reimbursement receipts, and more. By connecting to HelloID and enabling SSO, your users can seamlessly and securely access AFAS Pocket. Once logged into HelloID, users merely click the AFAS icon located on their personalized dashboard.

HelloID uses OpenID to connect to AFAS. As with all HelloID’s other SSO connections, multifactor authentication (MFA) may be applied at the portal or individual application levels for additional security.

## Additional Connector Information

For information on how to connect AFAS to HelloID and enable SSO, please refer to the HelloID Docs site:  
[https://docs.helloid.com/hc/en-us/articles/360024472653-AFAS-OpenID-Single-Sign-On-SSO-Configuration](https://docs.helloid.com/hc/en-us/articles/360024472653-AFAS-OpenID-Single-Sign-On-SSO-Configuration)

For additional information on AFAS connector commands, such as “GET” and “UPDATE,” please refer to the following GitHub links:  
[https://github.com/Tools4everBV/HelloID-Conn-Prov-Target-AFAS-Profit-Employees  
](https://github.com/Tools4everBV/HelloID-Conn-Prov-Target-AFAS-Profit-Employees)[https://github.com/Tools4everBV/HelloID-Conn-Prov-Target-AFAS-Profit-Users  
](https://github.com/Tools4everBV/HelloID-Conn-Prov-Target-AFAS-Profit-Users)[https://github.com/Tools4everBV/HelloID-Conn-Prov-Source-AFAS-Profit](https://github.com/Tools4everBV/HelloID-Conn-Prov-Source-AFAS-Profit)
 
