# SafeguardCustomPlatform

Support and documentation for custom platform management

-----------

<p align="center">
<i>Check out our <a href="../../wiki">wiki documentation</a> to get started with your own custom integration to Safeguard!</i>
</p>

-----------

## Introduction

Safeguard provides support for common platforms from which an asset
administrator can create assets and asset accounts for managing privileged
passwords.  However, sometimes customer environments include unique
applications, uncommon platforms/operating systems, or specialized
customizations that Safeguard does not include in its common platforms.  In
order to support assets that represent these scenarios, Safeguard includes a
custom platform feature which allows the asset administrator to write a
platform definition that instructs Safeguard on how to communicate with these
assets.  We call these platform definitions **custom platform scripts**.

<i>Get started quickly with one of our <a href="SampleScripts">sample scripts</a>.</i>

## Getting Started

The best place to start is to read the <a href="../../wiki">wiki documentation</a>
included in this repository.  The custom platform scripts themselves may be
thought of as an object model representing an intermediate language that is
executed by Safeguard to manage the asset.  The custom platform intermediate
language is similar to a parsed syntax tree.  Safeguard uses JSON to represent
this intermediate language object model to avoid complications and security
vulnerabilities related to parsing and interpreting a domain-specific language
or a common scripting language.

After reading the <a href="../../wiki">wiki documentation</a>, rather than writing a
custom platform script from scratch, the best approach may be to start with
a sample and modify it.  We include <a href="SampleScripts">sample custom
platform scripts</a> that are organized by the protocol used for managing the
asset.  Currently, Safeguard custom platforms support: 
<a href="SampleScripts/SSH">SSH</a>,
<a href="SampleScripts/Telnet">Telnet (TN3270)</a>, and
<a href="SampleScripts/HTTP">HTTP</a>.

## Telnet Sessions

Telnet includes extensions to the protocol for use with particular terminal
clients, e.g. TN3270 and TN5250.  The forms-based terminal applications that
run on platforms that communicate using these protocol extensions often
include custom forms that are used for user login.  In order to manage these
platforms or play passwords into these assets for privileged session connections
without exposing the password, Safeguard needs to have information about how
to parse the forms to find the required fields.

A custom platform script can be created for Safeguard for Privileged Passwords
in order to manage password check and change operations via Telnet or TN3270.

Safeguard for Privileged Sessions allows you to upload a pattern file that
can instruct Safeguard how to play in the password during privileged session
connections.

Sample <a href="PatternFiles">pattern files</a> are available for some common
platforms with the default configuration.  Pattern files nearly always require
some customization for your specific use case.
