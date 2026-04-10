# Guide to SafeguardCustomPlatform - HTTP Scripts

## Table of Contents  
[OneLogin_GRC_JIT_addon](#onelogin_grc_jit_addon)  
[Okta_WithDiscoveryAndGroupMembershipRestore](#okta_withdiscoveryandgroupmembershiprestore) 

## OneLogin_GRC_JIT_addon

This Solution Accelerator addon was created to implement JIT role elevation for OneLogin until it is available out-of-box in Safeguard.

### How does it work
The OneLogin_GRC_JIT_addon implements Restore/Suspend and Elevate/Demote functions. The ChangePassword function is also defined as it's a must-have for Custom Platform scripts, however it does nothing (only logs that it does nothing).

Changing the password is:
 * Either not necessary as the Account will only store a TOTP code, configured automatically by OneLogin.
 * Or if the base privileged Account is created & managed by the out-of-box Starling Connect connector for OneLogin, that will be managing the password.
 
The addon will be the Platform Types for additionally created Assets in Safeguard, each separate Asset representing a Role in OneLogin:

![SafeguardCustomPlatform](../../Images/http_oneloginjit_1.png)

Each privileged OneLogin User having permission to elevate into that Role needs to have an Account object created within the Asset representing the Role.

![SafeguardCustomPlatform](../../Images/http_oneloginjit_2.png)

(Note: the Assets could also represent groups of Roles.)

In SPP the Account shows up on the Access Request portal only if it has the password set. Hence each of these Accounts need to have a dummy password configured. 

The Users need to have Entitlements / Access Request Policies to the base privileged OneLogin Account as well as for the individual Accounts representing the Roles. This requires creating an Entitlement per User as at the time of writing this reamde (in SPP v8.2) the Accounts of neither the OneLogin platform Asset, nor the custom platform Assets can be added as Linked Accounts.

![SafeguardCustomPlatform](../../Images/http_oneloginjit_3.png)

When the User is requesting access to the privileged OneLogin Account, at the same time the desired Roles should also be selected. The privileged OneLogin Account will have the Roles assigned, once the subsequent access requests representing the Roles become available (after Pending Restore state).

![SafeguardCustomPlatform](../../Images/http_oneloginjit_4.png)

#### Demo video

<a href="https://raw.githubusercontent.com/OneIdentity/SafeguardCustomPlatform/master/Videos/http_oneloginjit_1.mp4" target="_blank">Watch demo video</a>


### About enabling/disabling the OneLogin user via a Safeguard Access Request
JIT enable/disable or elevate/demote tasks are implemented on the OneLogin_GRC_JIT_addon Asset/Accounts.

There are two typical setups:

1. When the Account objects are managed by OneLogin, all of them stored under a OneLogin_GRC_JIT_addon Asset:
	* In this scenario enable the *Suspend account when checked in* function under Password Profile > Change Password policy for the main privileged account. Do not configure JIT groups for this Accounts.
	* Configure the JIT group elevation for the Accounts on the Assets representing the Roles. Do not enable the *Suspend account when checked in* function for these Accounts.
	* Once the main -adm account is checked out, it gets activated. The Roles get assigned depending on which corresponding Asset is requested along with the main Account. Whilst the main Account is checked out, the User can request further Roles, or check any of them in, demoting that Role in OneLogin.

2. When the main Account is managed by the out-of-box Starling Connect connector for OneLogin, and only the Assets representing a Role are configured with the OneLogin_GRC_JIT_addon platform type:
	* In this case both the *Suspend account when checked in* function and the JIT groups should be configured on each of the Asset/Accounts representing a OneLogin Role.
	* Despite the main Account is checked out, it is still inactive in OneLogin. It will only be activated once an Asset/Account representing a Role gets checked out too, as the OneLogin_GRC_JIT_addon is the connector implementing JIT activation and elevation.
	* In case the Account is assigned to multiple Roles via requesting multiple Asset/Accounts representing a OneLogin Role, the User should not check in any of the Roles before finishing all activities because checking one of these requests in will not only demote the requested Role, but also deactivate the Account inside OneLogin.

### Configuration
It can be configured with two different approaches: 
* **Accounts are created by OneLogin through its Generic REST Connector.**
	* In this case the default Starling Connect connector for OneLogin is not used. Asset and Account objects are created by OneLogin, as well as the Entitlements and the Access Request Policies.
	* Every Role which you want to make available for the privileged OneLogin account is mapped to an Asset/Account object in Safeguard, automatically by OneLogin. Corresponding Entitlements and Access Request policies are also created by OneLogin.
	* OneLogin is automatically registering the TOTP for the privileged OneLogin account, as well as vaulting it in SPP (the TOTP seed is never exposed, users are technically forced to use the vaulted credential).
* **The base Account is created via the Discovery feature of the Starling Connect connector for OneLogin or in any other way, like via AD (in case the accounts are synchronized into OneLogin from AD).**
	* In this case the Asset/Account objects representing the Role/User pairs must be created manually, or via 3rd party automation, so as the Entitlements and Access Request Policies.
	* The TOTP seed for the base privileged OneLogin Account must be vaulted manually, or via 3rd party automation.

#### Configuration: Accounts are created by OneLogin through its Generic REST Connector

 1. Create the API Credential in OneLogin with Manage All permissions. This will be used as the service account for the Assets in Safeguard.
 2. Upload the custom platform script to SPP.

	![SafeguardCustomPlatform](../../Images/http_oneloginjit_5.png)

	
	![SafeguardCustomPlatform](../../Images/http_oneloginjit_6.png)



 3. Configure the OneLogin REST Connector for Safeguard and let it do the heavy-lifting Safeguard: Assets, Accounts, Entitlements, Access Request Policies, etc. Search the **One Identity Safeguard (OneLogin Account Onboarding)** and **One Identity Safeguard (OneLogin-Virtual AssetAccounts for JIT elevation)** connectors in the OneLogin Application Catalog.

	


With this, the User is now able to raise Access Requests in Safeguard which enables the Account in OneLogin and assigns the requested Roles.

#### Configuration: The base Account is created via the Discovery feature of the Starling Connect connector for OneLogin, or from Active Directory

1. Onboard the OneLogin Accounts to SPP in the preferred way, for example using the out-of-box Starling Connect connector for OneLogin. This is going to be the main Account object holding the actual secrets of the privileged OneLogin Account. Feel free to manage these Accounts as needed. The Accounts may also originate from AD so that we can configure RDP Apps. In case the status and password of the OneLogin account is in sync with AD, then you can also manage the corresponding AD accounts in SPP.

	![SafeguardCustomPlatform](../../Images/http_oneloginjit_7.png)


2. Create the API Credential in OneLogin with Manage All permissions. This will be used as the service account for the Assets in Safeguard.

3. Upload the custom platform script to SPP.

	![SafeguardCustomPlatform](../../Images/http_oneloginjit_8.png)

	
	![SafeguardCustomPlatform](../../Images/http_oneloginjit_9.png)

4. Create an Asset for each OneLogin Role, or combination of Roles, that the User has permission to elevate into. The platform type is the OneLogin_GRC_JIT_addon.

	As the Roles look like in OneLogin:

	![SafeguardCustomPlatform](../../Images/http_oneloginjit_10.png)


	As the corresponding Assets look like in Safeguard:

	![SafeguardCustomPlatform](../../Images/http_oneloginjit_11.png)


5. Create an Account on each of the these Assets with the same name as the original OneLogin Account. For example as shown on one of the Assets representing a OneLogin Role:

	![SafeguardCustomPlatform](../../Images/http_oneloginjit_12.png)


	Make sure that a dummy password is set on each of these Accounts otherwise these won't show up when raising an Access Request (note: the OneLogin_GRC_JIT_addon does not change the password of the Account, even if the Task is successfully completed).

	The Password Profile of these Accounts should do nothing with the password. No Check / No Change.

6. Configure the corresponding Role name in the JIT configuration of these Accounts. For example as shown on one of the Assets representing a OneLogin Role:

	![SafeguardCustomPlatform](../../Images/http_oneloginjit_13.png)

7. If the base OneLogin Account is managed through the originating AD Account, then create an Entitlement for password or pession (RDP App) access with the Users' Linked Accounts.

	![SafeguardCustomPlatform](../../Images/http_oneloginjit_14.png)

	![SafeguardCustomPlatform](../../Images/http_oneloginjit_15.png)

	![SafeguardCustomPlatform](../../Images/http_oneloginjit_16.png)

Don't forget creating the virtual asset to connect to:

	![SafeguardCustomPlatform](../../Images/http_oneloginjit_17.png)

Otherwise the Access Request Policy will be created in the per-user Entitlement together with the access to the virtual JIT Assets.

8. Create an Entitlement per each User. This is required as at the time of writing this readme (in SPP v8.2) the Accounts of a Custom Platfom Asset can't be configured as Linked Accounts.

	![SafeguardCustomPlatform](../../Images/http_oneloginjit_18.png)

9. Create a Dynamic Account Group for all the Role-specific Accounts of the User.

	![SafeguardCustomPlatform](../../Images/http_oneloginjit_19.png)

	![SafeguardCustomPlatform](../../Images/http_oneloginjit_20.png)


10. Create a password Access Request Policy into the Entitlement. In the Scope of this Access Request Policy, add the Dynamic Account Group of the User.
	
	![SafeguardCustomPlatform](../../Images/http_oneloginjit_21.png)

	![SafeguardCustomPlatform](../../Images/http_oneloginjit_22.png)


With this, the User is now able to raise Access Requests in Safeguard which enables the Account in OneLogin and assigns the requested Roles.

![SafeguardCustomPlatform](../../Images/http_oneloginjit_23.png)
	


## Okta_WithDiscoveryAndGroupMembershipRestore
This script had been implemented before the JIT Elevation functionality was available in Safeguard. Hence the configuration is cumbersome and does not work as JIT is confgured.

The script should be reworked a bit to reflect the out-of-box JIT configuration approach.
