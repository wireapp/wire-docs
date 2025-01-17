# 2022-05-23 - wire.com website outage

Last updated: 2022-05-25

On Monday, 2022-05-23 the Wire website wire.com was affected by an outage of our hosting provider.

This outage concerns **only wire.com** website and none of the services provided by Wire.

## Timeline

*06:00*: wire.com being down was detected by the Security Team<br />
\\\\
*06:46*: Our Hosting Provider was informed about wire.com being down<br />
\\\\
*07:03*: Our Hosting Provider initiated a server restart to mitigate<br />
\\\\
*07:08*: Restart of wire.com server failed due to problems on hypervisor (no additional details provided by upstream provider)<br />
\\\\
*07:23*: We changed the DNS record for wire.com to an old backup to restore basic functionality<br />
\\\\
*10:30*: Our Hosting Provider restored wire.com server<br />
\\\\
*11:20*: Our Hosting Provider informed us that the recent version of wire.com is reliably available again<br />
\\\\
*12:02*: We reverted the DNS changes, to point back to the recent version of wire.com

## Are Wire installations affected?

**Wire/wire-server was not affected by wire.com website outage.**
