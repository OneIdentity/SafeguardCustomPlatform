
# TN3270/TN5250 for SPP and SPS

Configuring SPP and SPS to start and record Telnet andTN3270/TN5250 sessions

## Introduction

TN3270 and TN5250 are both protocols that are still in wide use today.  The old style proprietary connected terminals are basically extinct, however the protocol for communicating to a mainframe is still supported through software terminal emulation over telnet ( [brief history](https://en.wikipedia.org/wiki/IBM_3270) ).  Telnet is a rudimentary protocol which does not lend itself to the same SPP/SPS integration experience that we currently have with SSH or RDP.  TN3270/5250 sessions start as a basic Telnet connection which then transform into a 3270 or 5250 connection after specific options and control characters are sent to establish the appropriate data streams.  Often the login experience is presented as a form which may prompt for user name, password as well as other optional information. 

This repository contains the Authentication/Authorization (AA) plugin that will allow SPS to validate the telnet session with SPP prior to pulling the credential from the SPP vault.  The repository also contains some example pattern files which are necessary for every telnet session connection.  They provide SPS with a details technical description of the login experience so that SPS can accurately detect and inject the user credentials during the form based login.

## SPS AA Plugin

The TN3270/5250 telnet connection policy will take advantage of the AA and Credstore plugin mechanism in the same way that these plugins have been used for SSH and RDP.  One difference is that while SSH and RDP use the same set of plugins, TN3270/5250 will use a new AA plugin.  The plugins are assigned to a TN3270/5250 connection policy in the same way that they are assigned to an SSH or RDP connection policy.  The plugins must be uploaded, referenced by an AA or Credstore policy and then the policy must be referenced by the connection policy that intends to use the plugins.  The main difference between the existing AA plugin for SSH/RDP and telnet, is that the plugins used by SSH/RDP assume that the connection policy uses in-band destination in order to determine the originating Safeguard vault, one-time token and destination server.  The TN3270/5250 AA plugin cannot make this same assumption.  Therefore, the new telnet AA plugin must prompt for the same information from the user at the time when the connection is established rather than relaying on the extraction of this information from a connection string.  The credential store plugin for telnet will remain the same as the plugin used by SSH/RDP.

## SPS Pattern Files

The login experience to a mainframe can vary from system to system.  In order to support the various types of login for a given mainframe, SPS requires that a custom pattern file be created, uploaded and referenced by the telnet connection policy. The pattern file describes the login experience of each system which includes the on screen location of the user name and password fields.  These fields must be identified through the use of very specific regular expressions that denote the field titles and EBCDIC control characters that delineate the fields.

```
Example Pattern File

{
    "name": "AS400",
    "description": "AS400 (TN3270)",
    "states":
    {
        "_START_": {
            "next_states": ["SIGN_ON_PAGE"],
            "type": "tn3270"
        },
        "SIGN_ON_PAGE": {
            "patterns": ["#40`Sign On`"],
            "side": "server",
            "next_states": ["USERNAME_ANCHOR"]
        },
        "USERNAME_ANCHOR": {
            "patterns": ["`User`[` `,`.`]*"],
            "side": "server",
            "next_states": ["PASSWORD_ANCHOR"]
        },
        "PASSWORD_ANCHOR": {
            "patterns": ["`Password`[` `,`.`,#00]*#29..(?P<modifyattr>.)"],
            "side": "server",
            "next_states": ["USERNAME"]
        },
        "USERNAME": {
            "patterns": ["#11..(?P<username>[^#00-#40]*)"],
            "event": "username",
            "side": "client",
            "next_states": ["PASSWORD"]
        },
        "PASSWORD": {
            "patterns": ["#11.*#11..(?P<password>[^#00-#3f]*)"],
            "event": "password",
            "side": "client",
            "next_states": ["SUCCESS", "FAILURE"]
        },
        "SUCCESS": {
            "patterns": ["`IBM i Main Menu`"],
            "side": "server",
            "event": "success"
        },
        "FAILURE": {
            "patterns": ["#40`Sign On`"],
            "side": "server",
            "event": "failure",
            "next_states": ["USERNAME"]
        }
    }
}
```

Each pattern file must have entries for "Name", "Description" and "States".  The name and description are self-explanatory, however the states can be very complex.  Basically, the states section is a list of states that describe not only the state of the login process but also the location of each critical field on the login form (ie. User Name and Password).  The states section must begin with the state "_START_" and must conclude with a "SUCCESS" state and optionally a "FAILURE" state.  Each state that is defined between the "_START_" and "SUCCESS" states, defines a state in the order of appearance in the login form.  Each state contains a regular expression, a "server" or "client" response designator, optionally an event and finally a reference to the next expected state or states.  The explanation below describes the various states of the pattern file example above:

- **SIGN_ON_PAGE** - Includes a regular expression that if matched, determines that the login form has been displayed.
- **USERNAME_ANCHOR** - Identifies the user name field within the form.
- **PASSWORD_ANCHOR** - Identifies the location of the password field within the form.  Important note about this regular expression.  The capture group "modifyattr" is a special capture that is evaluated and modified by PSM.  The "modifyattr" capture must identify the Field Attribute byte of the password field.  This byte contains the "Modified" attribute of the field which allows PSM to determine if the field has been modified by the user or not.  If a field has not been modified by the user, then PSM will attempt to retrieve the password credential from the credential store that is referenced from the PSM telnet connection policy.  Once the credential has been retrieved from the credential store, PSM will set the modified attribute to true so that it can inject the credential into the response and notify the server that the field contains a value.  Otherwise, PSM will pass the value of the password credential field to the target server.
- **USERNAME** - Includes a regular expression that uniquely locates and captures the user name from the client response.  It uses a capture group named "username" and must specify the "username" event as well.  This event notifies PSM that the user name has been successfully captured from the client response.  Since this state is meant to capture a client response, the "side" value is set to "client".
- **PASSWORD** - Includes a regular expression that uniquely locates and captures the password from the client response.  It uses a capture group named "password" and must specify the "password" event as well.  This event notifies PSM that the password has been successfully captured from the client response.  However, if the password capture is empty, then PSM will attempt to retrieve the password from the credential store that is associated with the telnet connection policy.  Otherwise, the contents of the password field are passed through to the target server.  This state is also meant to capture a client response and therefore the "side" value is set to "client".  Also notice that the "next_states" value include two states rather than just one, indicating that the next state may result in "SUCCESS" or "FAILURE".
- **SUCCESS** - Includes a regular expression that if matched, determines that the result of the login attempt was successful.
- **FAILURE** - Includes a regular expression that if matched, determines that the result of the login attempt failed and instructs PSM to return back to the "USERNAME" state so that the login tracking can retry.

One important note about the ordering of the states.  Each "side" transition from "server" to "client" must follow the flow of server response vs. user input.  In other words, if the server is instructing the TN3270/5250 emulator to display a form or data and the state expects to match specific content within the server's instructions (data stream), then the "side" value must be set to "server".  However, when the user enters data into the form and hits the "enter" key to send the data back to the server, the state that is expecting to match specific data within the client response, must set the "side" to "client".  A more simplistic way of looking at these transitions is that each transition from server to client happens when the user enters a response to the server's prompt and hits the enter key to send the response. See the two scenarios below: (The pattern file example above follows the second scenario)

 1. Start

    - Side:Server - Prompt for user name →

    - ← Side:Client - Respond with user name value

    - Side:Server - Prompt for password →

    - ← Side:Client - Respond with password value

    - Success or Failure

OR

 2. Start

    - Side:Server - Prompt for user name and password →

    - ← Side:Client - Respond with user name and password values

    - Success or Failure


SPS analyzes each data packet as they flow from the server to the client and vice-versa.  With each packet that is analyzed, SPS determines if it is a server-side packet or a client-side packet and applies the regular expression of the current state.  If the state matches, SPS moves to the next state.  If the state doesn't match, SPS remains on the current state and waits for another packet to analyze.  Each regular expression is evaluated against the entire data packet.  In other words, the regular expression that is contained in each state is completely unaware of the regular expression of any other state or whether a previous regular expression matched or not.  If data values from a previous state need to be referenced in a subsequent state, capture groups and value substitution (ie. {value}) within the regular expression, can be used.  Each regular expression must uniquely identify a given string or location of an entry field within the entire data packet.  The use of some control characters within the regular expression may be necessary,rather than just matching on alpha-numeric characters.  SPS uses the [EBCDIC 037](https://en.wikipedia.org/wiki/EBCDIC_037) character set .  When reading the character set table, the high order byte represents the row in the table and the low order byte represents the column.  A few of the more important control characters are:

    #29 (SFE)Start Field Extended (contains the modified field attribute)
    #11 (SBA)Set Buffer Address (identifies a field location)
    #1d (SF)Start Field (contains the modified field attribute)

These control characters and their accompanying data values, can be used to uniquely identify fields and values within a form.

## SPS Connection Policy

Due to the uniqueness of each system and pattern file, each mainframe system that is supported by SPS for session recording may require a unique telnet connection policy rather than a single generic connection policy.  Also, the fact that TN3270/5250 does not support in-band destination means that each connection policy must include a fixed destination IP address or be configured for transparent mode.  In other words, while any SSH/RDP connection can be established through a single generic connection policy, each TN3270/5250 will require it's own unique connection policy.  The Safeguard policy admin will be required to know which SPS connection policy must be assigned to a specific access policy that is defined in SPP.

### - Enable Telnet on SPS 6.1 and above - Adding plugin and connection policies

Starting a TN3270/5250 session from SPP will require SPS 6.1 or above.  SPS 6.0 does not include the current REST endpoint permission that SPP needs in order to query SPS for the telnet connection policy information.  This has been enabled in SPS 6.1 and above.  The following steps outline the manual process for configuring the Telnet AA plugin, pattern files and connection policies on SPS:

1. Download the Telnet AA plugin
2. Download the example pattern files or develop your own
3. Open the Web UI for SPS
    - Navigate to Basic Settings->Plugins
    - Upload the telnet AA plugin that was previously downloaded (SGAATelnet.zip)
4. Navigate to Policies->AA Plugin Configuration
    - Click the '+' button to add a new policy
    - Name the policy 'SGAATelnet'
    - Select the SGAATelnet plugin from the Plugin dropdown
    - Click the Commit button
5. Navigate to Telnet Control->Pattern Sets
    - Upload the pattern file(s)
6. Navigate to Telnet Control->Authentication Policies
    - Click the '+' button to add a new policy
    - Name the policy
    - Click the checkbox for Extract username from the traffic:
    - Click the Select target devices
    - Select one of the available pattern files, click <<Add, Click OK
    - Repeat the above steps for each desired pattern file configuration
    - Click the Commit button
7. Navigate to Telnet Control->Connections
    - Click the '+' button to add a new policy
    - Name the policy
    - Add from and to addresses (such as 0.0.0.0/0 on port 2323 for any address on port)
    - Select Target: Use fixed address: \<mainframe address> and port: \<port>
    - Scroll down and set Audit: to safeguard_default (this selection may not be available until after the first join.  If so, you will need to leave it as default and change it later.)
    - Set Credential Store: safeguard_default (this selection may not be available until after the first join.  If so, you will need to leave it blank and change it later.)
    - Set the Authentication policy to an authentication policy that was defined in step 6
    - Set the AA plugin: to SGAATelnet
    - Set the Usermapping policy: to safeguard_default (this selection may not be available until after the first join.  If so, you will need to leave it blank and change it later)
    - Click the Commit button
8. Navigate to Basic Settings->Local Services->Cluster Interface
    - Click 'Enable'
    - Select the default IP address from the Listening addresses: dropdown
    - Click the Commit button
9. Navigate to Basic Settings->Cluster manangement
    - Click the 'Promote' button
    - Click the OK button when it becomes enabled
    - Join to an SPP appliance as needed
10. After joining the SPS appliance to the SPP appliance, navigate to Telnet Control->Connections and fill in the policy references if needed (see step 7)
