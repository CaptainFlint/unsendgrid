#!/usr/bin/perl

use strict;
use warnings;

use FindBin;
use File::Temp qw/tempfile/;
use MIME::Base64;
use LWP::UserAgent;

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
		my $x_sg_range = (($lns =~ m/^X-SG-EID: /) ... ($lns =~ m/^\S/));
		if (!($x_sg_range && ($x_sg_range !~ m/E0$/))) {
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

my $ua = LWP::UserAgent->new('max_redirect' => 0, 'requests_redirectable' => [], 'timeout' => 10);

sub unsendgrid_link($) {
	my ($lnk) = @_;
	my $resp = $ua->head($lnk);
	if ($resp->is_redirect) {
		return ($resp->header('Location') || $lnk);
	}
	else {
		return $lnk;
	}
}

sub unsendgrid_all($) {
	my ($src) = @_;
	if ($src eq '') {
		return '';
	}
	my $msg = decode_base64($src);
	$msg =~ s!https://[a-z0-9.]+\.sendgrid\.net/[^\'\"<>\s]*!unsendgrid_link($&)!ges;
	return encode_base64($msg);
}

my $fsm_state = {'pos' => 'hdrs', 'data' => ''};
while (my $ln = <>) {
	my $lns = ($ln =~ s/[\r\n]+//gr);
	$fsm->{$fsm_state->{'pos'}}->($fsm_state, $ln);
}

print $fsm_state->{'data'};

my $fileprefix = sprintf('mail-%04d%02d%02d-%02d%02d%02d-XXXXXX', $year + 1900, $mon + 1, $mday, $hour, $min, $sec);
my ($fh, $filename) = tempfile($fileprefix, SUFFIX => '.eml', DIR => $FindBin::Bin . '/mail', UNLINK => 0);
print $fh $fsm_state->{'data'};
close($fh);
