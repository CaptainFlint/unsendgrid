#!/usr/bin/perl

use strict;
use warnings;

use FindBin;
use File::Temp qw/tempfile/;

my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime();

open(F, '>>', $FindBin::Bin . '/log') or die;
print F sprintf("[%04d%02d%02d-%02d%02d%02d] started with args: '%s'\n", $year + 1900, $mon + 1, $mday, $hour, $min, $sec, join(', ', @ARGV));
close(F);

exit(1) if -f $FindBin::Bin . '/stop';

my $data = '';
my $in_headers = 1;
while (my $ln = <>) {
	my $lns = ($ln =~ s/[\r\n]+//gr);
	if ($lns eq '') {
		$in_headers = 0;
	}
	if ($in_headers) {
		my $x_sg_range = (($lns =~ m/^X-SG-EID: /) ... ($lns =~ m/^\S/));
		# Skip X-SG-EID header
		next if ($x_sg_range && ($x_sg_range !~ m/E0$/));
	}
	$data .= $ln;
}

print $data;

my $fileprefix = sprintf('mail-%04d%02d%02d-%02d%02d%02d-XXXXXX', $year + 1900, $mon + 1, $mday, $hour, $min, $sec);
my ($fh, $filename) = tempfile($fileprefix, SUFFIX => '.eml', DIR => $FindBin::Bin . '/mail', UNLINK => 0);
print $fh $data;
close($fh);
