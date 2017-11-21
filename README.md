# OCS Agent Unix Packager

<p align="center">
  <img src="https://cdn.ocsinventory-ng.org/common/banners/banner660px.png" height=300 width=660 alt="Banner">
</p>

<h1 align="center">OCS Agent Standalone Unix Packager</h1>
<p align="center">
  <b>Some Links:</b><br>
  <a href="http://ask.ocsinventory-ng.org">Ask question</a> |
  <a href="https://www.ocsinventory-ng.org/?utm_source=github-ocs">Website</a> |
  <a href="https://www.ocsinventory-ng.org/en/#ocs-pro-en">OCS Professional</a>
</p>

## Description

The aim of this script is to create a all in one package to be deployed on every Linux machine.
The package embeds compiled Perl for the related OS, OCS Agent perl package, and all required perl mudules.

* packageOCSAgent.config: packager configuration
    * PROXY_HOST if you have direct Internet connection
    * OCS_INSTALL_DIR: OCS Agent installation directory
    * PERL_VERSION: Perl version you want to compile and embed in OCS package
    * PERL_DL_LINK: Perl download link
    * OCSAGENT_DL_LINK: OCS Agent download link
    * NMAP_DL_LINK: Nmap download link
* PerlModulesDownloadList.txt: download URL for all Perl modules dependencies
* packageOCSAgent.sh: packager script

## Usage

As root user
```shell
#./packageOCSAgent.sh
```

Output is a tar/gz archive: ocsinventory-agent_*LinuxDistribution*_*MajorVersion*.tar.gz

## Todo

1. Add interactive configuration
2. Bypass current limitations

## Current Limitation

1. Package does not embed SSL Perl livrary to connect to OCS Server with SSL.
2. nmap command line path is not referenced in Perl module, thus, IP Discovery function does not work

