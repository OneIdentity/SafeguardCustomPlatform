
# TN3270/TN5250 for SPP and SPS

This document describes how to configure Safeguard for Privileged Passwords (SPP) and Safeguard for Privileged Sessions (SPS) to start and record mainframe telnet and TN3270/TN5250 sessions.

For additional details, see:

 * [SPP Administration Guide](https://support.oneidentity.com/technical-documents/one-identity-safeguard/administration-guide), "How do I set up telnet and TN3270/TN5250 session access requests"

 * [SPS Administration Guide and Installation Guides](https://support.oneidentity.com/one-identity-safeguard-for-privileged-sessions/technical-documents)

## Introduction

Safeguard for Privileged Passwords (SPP) supports session access requests to communicate with mainframes using software terminal emulation telnet sessions and TN3270/TN5250 over telnet sessions.

TN3270/TN5250 sessions start as a basic telnet connection which then transform into a 3270 or 5250 connection after specific options and control characters are sent to establish the appropriate data streams. Often, the login experience is presented as a form which may prompt for the username, password, and, potentially, other information.

This One Identity repository provides:

   * The Authentication/Authorization (AA) plugin that allows SPS to validate the telnet session with SPP prior to pulling the credential from the SPP vault.

   * Template pattern files which are necessary for every telnet session connection. They provide SPS with a detailed technical description of the login experience so that SPS can accurately detect and inject the user credentials during the form-based login. Template pattern files are provided for information only. In conjunction with One Identity Professional Services, you will create customized telnet and TN3270/TN5250 pattern files.

## Requirements

**Versions**

  * Safeguard for Privileged Passwords (SPP) version 2.9 or higher

  * Safeguard for Privileged Sessions (SPS) version 6.1 or higher </br> SPS 6.0 does not include the current REST endpoint permission that SPP needs to query SPS for the telnet connection policy information. This has been enabled in SPS 6.1 or higher.

**Engagement with One Identity Professional Services**

As an older protocol, telnet does not lend itself to the same SPP/SPS integration experience for SSH or RDP so experienced help is needed to ensure a successful and timely outcome. Engagement with One Identity Professional Services is required for assistance with configurations and installation as well as help with plug-in use, policy creation, pattern files development, shortcut suggestions, and best practices advice. 

## SPS AA Plugin

TN3270/TN5250 requires a different AA plugin than the SSH an RDP plugin. The main difference between the AA plugin for SSH/RDP and the AA plugin for telnet is that the plugin used by SSH/RDP assumes that the connection policy uses in-band destination in order to determine the originating Safeguard vault, the one-time token, and the destination server. The TN3270/TN5250 AA plugin cannot make this assumption. Therefore, the telnet AA plugin prompts for the information from the user when the connection is established rather than relying on the extraction of this information from a connection string. The credential store plugin for telnet is the same as the plugin used by SSH/RDP.

The TN3270/TN5250 telnet connection policy takes advantage of the AA and credstore plugin mechanism in a similar way that these plugins are used for SSH and RDP. The plugins are assigned to a TN3270/TN5250 connection policy in the same way that plugins are assigned to an SSH or RDP connection policy. The plugin must be uploaded and referenced by an AA or credstore policy. Then, the policy that references the plugin must, in turn, be referenced by the connection policy that will use the plugin.

## SPS Pattern Files

The login experience to a mainframe can vary from system to system. In order to support the various types of login for a given mainframe, SPS requires that a custom pattern file be created, uploaded, and referenced by the telnet connection policy. The pattern file describes the login experience of each system which includes the on-screen location of the username and password fields. These fields must be identified by using very specific regular expressions that denote the field titles and EBCDIC control characters that delineate the fields.

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

Each pattern file must have entries for "name", "description", and "states". The name and description are self-explanatory; however, the states can be very complex. Basically, the states section is a list of states that describe not only the state of the login process but also the location of each critical field on the login form (for example, username and password). The states section must begin with the state "_START_" and must conclude with a "SUCCESS" state and, optionally, a "FAILURE" state. Each state that is defined between the "_START_" and "SUCCESS" states defines a state in the order of appearance in the login form.

Each state contains:

   * A regular expression
   * A "server" or "client" response designator
   * An event (optional)
   * A reference to the next expected state or states

The explanation below describes the various states of the pattern file example above:

- **SIGN_ON_PAGE**: Includes a regular expression that, if matched, determines that the login form has been displayed.

- **USERNAME_ANCHOR**: Identifies the username field within the form.

- **PASSWORD_ANCHOR**: Identifies the location of the password field within the form. <br/>*IMPORTANT NOTE about this regular expression:* The capture group "modifyattr" is a special capture that is evaluated and modified by SPS. The "modifyattr" capture must identify the Field Attribute byte of the password field. This byte contains the "modified" attribute of the field which allows SPS to determine if the field has been modified by the user or not. If a field has not been modified by the user, then SPS will attempt to retrieve the password credential from the credential store that is referenced from the SPS telnet connection policy. Once the credential has been retrieved from the credential store, SPS will set the modified attribute to true so that it can inject the credential into the response and notify the server that the field contains a value. Otherwise, SPS will pass the value of the password credential field to the target server.

- **USERNAME**: Includes a regular expression that uniquely locates and captures the username from the client response. It uses a capture group named "username" and must specify the "username" event as well. This event notifies SPS that the username has been successfully captured from the client response. Since this state is meant to capture a client response, the "side" value is set to "client".

- **PASSWORD**: Includes a regular expression that uniquely locates and captures the password from the client response. It uses a capture group named "password" and must specify the "password" event as well. This event notifies SPS that the password has been successfully captured from the client response. However, if the password capture is empty, then SPS will attempt to retrieve the password from the credential store that is associated with the telnet connection policy. Otherwise, the contents of the password field are passed through to the target server. This state is also meant to capture a client response and therefore the "side" value is set to "client". Also notice that the "next_states" value include two states rather than just one, indicating that the next state may result in "SUCCESS" or "FAILURE".

- **SUCCESS**: Includes a regular expression that, if matched, determines that the result of the login attempt was successful.

- **FAILURE**: Includes a regular expression that, if matched, determines that the result of the login attempt failed and instructs SPS to return to the "USERNAME" state so that the login tracking can retry.

*IMPORTANT NOTE about the ordering of the states:* Each "side" transition from "server" to "client" must follow the flow of server response versus the user input. In other words, if the server is instructing the TN3270/TN5250 emulator to display a form or data and the state expects to match specific content within the server's instructions (data stream), then the "side" value must be set to "server". However, when the user enters data into the form and presses the "enter" key to send the data back to the server, the state that is expecting to match specific data within the client response must set the "side" to "client". A more simplistic way of looking at these transitions is that each transition from server to client happens when the user enters a response to the server's prompt and presses the enter key to send the response. See the two scenarios which follow. (The pattern file example shown earlier aligns with the second example which follows.)

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

SPS analyzes each data packet as they flow from the server to the client and vice-versa. With each packet that is analyzed, SPS determines if it is a server-side packet or a client-side packet and applies the regular expression of the current state. If the state matches, SPS moves to the next state. If the state doesn't match, SPS remains on the current state and waits for another packet to analyze. Each regular expression is evaluated against the entire data packet. In other words, the regular expression that is contained in each state is completely unaware of the regular expression of any other state or whether a previous regular expression matched or not. If data values from a previous state need to be referenced in a subsequent state, captured groups and value substitution (for example, {value}) within the regular expression can be used. Each regular expression must uniquely identify a given string or location of an entry field within the entire data packet. The use of some control characters within the regular expression may be necessary, rather than just matching on alpha-numeric characters. SPS uses the [EBCDIC 037](https://en.wikipedia.org/wiki/EBCDIC_037) character set. When reading the character set table, the high order byte represents the row in the table and the low order byte represents the column. A few of the more important control characters are:

    #29 (SFE)Start Field Extended (contains the modified field attribute)

    #11 (SBA)Set Buffer Address (identifies a field location)

    #1d (SF)Start Field (contains the modified field attribute)

These control characters and their accompanying data values, can be used to uniquely identify fields and values within a form.

## SPS Connection Policy

Due to the uniqueness of each system and pattern file, each mainframe system that is supported by SPS for session recording may require a unique telnet connection policy rather than a single generic connection policy. Also, the fact that TN3270/TN5250 does not support in-band destination means that each connection policy must include a fixed destination IP address or be configured for transparent mode. In other words, while any SSH/RDP connection can be established through a single generic connection policy, each TN3270/TN5250 will require its own unique connection policy. The SPP Policy Administrator must know which SPS connection policy must be assigned to a specific access policy defined in SPP.

For additional details on connection policies, see:

 * [SPP Administration Guide](https://support.oneidentity.com/technical-documents/one-identity-safeguard/administration-guide), "How do I set up telnet and TN3270/TN5250 session access requests"

 * [SPS Administration Guide and Installation Guides](https://support.oneidentity.com/one-identity-safeguard-for-privileged-sessions/technical-documents)

### **Steps to add plugin and connection policies to enable telnet**

Starting a TN3270/TN5250 session from SPP 2.9 or higher requires SPS 6.1 or higher. The following steps outline the manual process for configuring the telnet AA plugin, pattern files, and connection policies on SPS.

1. Download the telnet AA plugin (SGAATelnet.zip).
2. Download the example pattern files and customize them, as needed, or develop your own pattern files.
3. Open the web user interface (UI) for SPS.
    - Navigate to **Basic Settings | Plugins | Upload/Update Plugins**.
    - Upload the telnet AA plugin that was previously downloaded (SGAATelnet.zip).
4. Navigate to **Policies | AA Plugin Configuration**.
    - Click **+ Add** to add a new policy.
    - Name the policy 'SGAATelnet'.
    - In **Plugin**, select the SGAATelnet plugin.
    - Click **Commit**.
5. Navigate to **Telnet Control | Pattern Sets**.
    - Click **Upload** to upload the pattern file(s).
6. Navigate to **Telnet Control | Authentication Policies**.
    - Click **+ Add** to add a new policy.
    - Name the policy.
    - Select **Extract username from the traffic**.
    - Click the **Select target devices**.
    - Select one of the available pattern files, click **Add**, and click **OK**.
    - Repeat the above steps for each desired pattern file configuration.
    - Click **Commit**.
7. Navigate to **Telnet Control | Connections**.
    - Click **+ Add** to add a new policy.
    - Name the policy.
    - Add from and to addresses (such as 0.0.0.0/0 on port 2323 for any address on port).
    - Select **Target** and **Use fixed address** \<mainframe address> and **Port** \<port>.
    - Scroll down and set **Audit** to <span style="font-family:courier; ">safeguard_default</span>. (This selection may not be available until after the first join. If so, you will need to leave it as it defaults and change it later.)
    - Set **Credential Store** <span style="font-family:courier; ">-safeguard_default</span> (This selection may not be available until after the first join. If so, you will need to leave it blank and change it later.)
    - Set the **Authentication Policy** to an authentication policy that was defined in via step 6 using **Telnet Control | Authentication Policies**.
    - Set the **AA plugin** to <span style="font-family:courier; ">SGAATelnet</span>.
    - Set the **Usermapping policy** to <span style="font-family:courier; ">safeguard_default</span> (This selection may not be available until after the first join. If so, you will need to leave it blank and change it later.)
    - Click **Commit**.
8. Navigate to **Basic Settings | Local Services | Cluster Interface**.
    - Click **Enable**.
    - In **Listening address**, select the default IP address.
    - Click **Commit**.
9. Navigate to **Basic Settings | Cluster management**.
    - Click **Promote**.
    - Click **OK** when it becomes enabled.
    - Join to an SPP appliance, as needed.
10. After joining the SPS appliance to the SPP appliance, navigate to **Telnet Control | Connections** and fill in the policy references if needed (see step 7).
