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

### Script installation and configuration

* First of all, you need to install Perl on your machine. I tested this with
  ActivePerl 5.26.1.
* Second, you need to get a binary `curl.exe`.
* Finally, not required but recommended, some application that allows to run
  console applications without showing the console window (otherwise console
  will keep popping up for every processed message). I'm using my self-written
  application [hideconsole_hdls](https://github.com/CaptainFlint/hideconsole_hdls).
  Make sure the application redirects the target stdout into its own output.

Edit the `unsendgrid.pl` script and put the path to `curl.exe` into the variable
`$curl_exe`, then update the `$curl_wrapped` variable to use the hideconsole
program with correct parameters.

Now all you need to do is configure The Bat!

Open the Sorting Office for the mailbox that receives the SG-scrambled mail and
create two rules as follows (of course, this is just a template; you can specify
any additional criteria or actions if you need):

##### Rule 1:
* Condition:
  * Header field: `X-SG-EID` match: `.`
* Actions:
  * Run external action
    * Command line: `C:\Perl\bin\wperl.exe C:\path\to\unsendgrid.pl %1`
    * [ ] Hide the process
    * [ ] Pass the message as the input stream (stdin)
    * [X] Wait for completion
      * [X] Import the process' stdout as an RFC 822 message if the process finishes normally
      * Destination folder: _(specify here the folder you want)_
  * Delete the message

##### Rule 2:
* Condition:
  * Header field: `X-SG-EID-Replacement` match: `.`
* Actions:
  * Mark the message as unread

**Explanations:**

The first rule makes The Bat! run the **UnSendGrid** script for each message
that has a non-empty header `X-SG-EID` (added by SG). The message will be saved
into a temporary file and passed as command line argument to the script which
will form a new mail message with unscrambled links and dump it into standard
output. The Bat! then, according to the options specified, will fetch this
output and import the resultant message into the mailbox. The original letter
will then be deleted. You might want to hold off of that "Delete" action until
you tested the script and rules thoroughly and made sure everything works as you
want it to.

The newly imported message is initially marked as read, and I could not find any
option in The Bat! to mark it unread by default. So, I implemented a workaround:
when the script deletes the `X-SG-EID` header from the message it adds a
replacement header `X-SG-EID-Replacement` to distinguish the new messages. So,
the second rule matches all mail with this new header and forcibly marks them
as unread.
