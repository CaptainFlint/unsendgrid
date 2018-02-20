#!/usr/bin/perl

use strict;
use warnings;

my $curl_exe = "C:/Programs/Git/mingw64/bin/curl.exe";
my $curl_wrapped = "\"C:/Programs/CaptainFlintSW/hideconsole_hdls.exe\" \"$curl_exe\"";

use FindBin;
use File::Temp qw/tempfile/;
use MIME::Base64;

my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime();

open(F, '>>', $FindBin::Bin . '/log') or die;
print F sprintf("[%04d%02d%02d-%02d%02d%02d] started with args: '%s'\n", $year + 1900, $mon + 1, $mday, $hour, $min, $sec, join(', ', @ARGV));
close(F);

exit(1) if -f $FindBin::Bin . '/stop';

my $fsm = {
	'hdrs' => sub ($$) {
		my ($fsm_state, $ln) = @_;
		my $lns = ($ln =~ s/[\r\n]+//gr);
		# Skip X-SG-EID header
		# Important! This range includes the whole X-SG-EID plus the first line of the NEXT header
		my $x_sg_range = (($lns =~ m/^X-SG-EID: /) ... ($lns =~ m/^\S/));
		if ($x_sg_range && ($x_sg_range !~ m/E0$/)) {
			# If inside the header (that is, inside the range, but not on the last line of it)...
			if ($lns =~ m/^X-SG-EID: /) {
				# ...and we are on the first line, add the replacement header
				$fsm_state->{'data'} .= "X-SG-EID-Replacement: empty\r\n";
			}
		}
		else {
			# If we are outside the header just add the current line to output
			$fsm_state->{'data'} .= $ln;
		}
		if ($lns eq '') {
			$fsm_state->{'pos'} = 'body';
		}
	},
	'body' => sub ($$) {
		my ($fsm_state, $ln) = @_;
		my $lns = ($ln =~ s/[\r\n]+//gr);
		$fsm_state->{'data'} .= $ln;
		if (($lns =~ m/^--/) && ($lns !~ m/--$/)) {
			$fsm_state->{'pos'} = 'attach_hdrs';
		}
	},
	'attach_hdrs' => sub ($$) {
		my ($fsm_state, $ln) = @_;
		my $lns = ($ln =~ s/[\r\n]+//gr);
		$fsm_state->{'data'} .= $ln;
		if ($lns eq '') {
			$fsm_state->{'pos'} = 'attach_body';
			$fsm_state->{'b64'} = '';
		}
	},
	'attach_body' => sub ($$) {
		my ($fsm_state, $ln) = @_;
		my $lns = ($ln =~ s/[\r\n]+//gr);
		$fsm_state->{'b64'} .= $lns;
		if ($lns eq '') {
			$fsm_state->{'pos'} = 'body';
			$fsm_state->{'data'} .= unsendgrid_all($fsm_state->{'b64'}) . $ln;
			$fsm_state->{'b64'} = '';
		}
	},
};

# TODO: Check that the command line does not exceed 8192 symbols; split if it does.
sub unsendgrid_all($) {
	my ($src) = @_;
	if ($src eq '') {
		return '';
	}
	my $msg = decode_base64($src);
	# Extract all the SG links
	my @msg_parts = split(m!(https://[a-z0-9.]+\.sendgrid\.net/wf/click[^\'\"<>\s]*)!, $msg);
	# The links are regexp groups, so they are at odd places in the array (1, 3, 5...)
	my $curl_cmdline = "$curl_wrapped -I";
	for (my $i = 1; $i < scalar(@msg_parts); $i += 2) {
		$curl_cmdline .= ' "' . $msg_parts[$i] . '"';
	}
	my @curl_out = `$curl_cmdline`;
	my $i = -1;
	for my $ln (@curl_out) {
		$ln =~ s/[\r\n]+//g;
		if ($ln =~ m/^HTTP\/\d+\.\d+/) {
			# Response for the next URL
			$i += 2;
			next;
		}
		if ($ln =~ m/^Location:\s*(.*)/) {
			$msg_parts[$i] = $1;
			next;
		}
	}
	return encode_base64(join('', @msg_parts), "\r\n");
}

binmode(STDOUT);

my $fsm_state = {'pos' => 'hdrs', 'data' => ''};
my $fin;
open($fin, '<', $ARGV[0]) or die "Failed to open file '$ARGV[0]' for reading: $!";
binmode($fin);
while (my $ln = <$fin>) {
	$fsm->{$fsm_state->{'pos'}}->($fsm_state, $ln);
}
close($fin);

print $fsm_state->{'data'};

my $fileprefix = sprintf('mail-%04d%02d%02d-%02d%02d%02d-XXXXXX', $year + 1900, $mon + 1, $mday, $hour, $min, $sec);
my ($fh, $filename) = tempfile($fileprefix, SUFFIX => '.eml', DIR => $FindBin::Bin . '/mail', UNLINK => 0);
binmode($fh);
print $fh $fsm_state->{'data'};
close($fh);
