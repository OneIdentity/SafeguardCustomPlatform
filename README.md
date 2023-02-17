# SafeguardCustomPlatform

Support and documentation for custom platform management

-----------

<p align="center">
<i>Check out our <a href="../../wiki">wiki documentation</a> to get started with your own custom integration to Safeguard!</i>
</p>

-----------

## Support

One Identity open source projects are supported through [One Identity GitHub issues](https://github.com/OneIdentity/SafeguardCustomPlatform/issues) and the [One Identity Community](https://www.oneidentity.com/community/). This includes all scripts, plugins, SDKs, modules, code snippets or other solutions. For assistance with any One Identity GitHub project, please raise a new Issue on the [One Identity GitHub project](https://github.com/OneIdentity/SafeguardCustomPlatform/issues) page. You may also visit the [One Identity Community](https://www.oneidentity.com/community/) to ask questions.  Requests for assistance made through official One Identity Support will be referred back to GitHub and the One Identity Community forums where those requests can benefit all users.

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

Telnet Pattern Files have been moved to the [SafeguardAutomation](https://github.com/OneIdentity/SafeguardAutomation/tree/master/Terminal%20Pattern%20Files) repository.
