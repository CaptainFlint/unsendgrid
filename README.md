## UnSendGrid

This is a script for decrypting the SendGrid links from E-mail.

This script is designed to post-process E-mail messages created by SendGrid
service ("SG" from now on). To avoid spam-detect this service replaces all links
in the message with fuzzy redirects which cannot be easily deciphered and has to
be clicked on to see where they lead. Even worse, these links may expire and you
will never even know what the actual link used to be, making the whole E-mail
message just a bulk of useless rubbish.

The Bat! offline E-mail client has ability to call external scripts to
post-process E-mail messages. Unfortunately, it is not very user-friendly, but
it works. I don't know about other clients, though.

### The Bat! configuration

**TODO**

```
$$$$ TB! Message Filter $$$$
beginFilter
UID: [4EC1DDA2.01D3A424.15D0827B.643A7C6B]
Name: Anti-SendGrid
Filter: {\0D\0A\20`7`X-SG-EID`2`.\0D\0A}
RunExternal Wait ImportResult CmdLine C:\5CPrograms\5CPerl\5Cbin\5Cwperl.exe\20D:\5Cdevel\5CPerl\5Cunsendgrid\5Cunsendgrid.pl\20%1 folder \5C\5CGmail\5CInbox\5CRSDN
IsActive
Ignore
endFilter

$$$$ TB! Message Filter $$$$
beginFilter
UID: [EF0E5F5B.01D3A987.5AAF71A7.0947D848]
Name: Anti-SendGrid-Post
Filter: {\0D\0A\20`7`X-SG-EID-Replacement`2`.\0D\0A}
MarkUnread
IsActive
Ignore
endFilter
```
