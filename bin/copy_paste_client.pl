#!/usr/bin/env perl

use strict;
use Crypt::JWT qw(encode_jwt decode_jwt);
use IO::Socket;
use Getopt::Long;
use warnings;

my $cmd = shift;

GetOptions(
	"force_newline|f" => \my $force_newline
);

my $data = "";
my $size = 0;

if ($cmd eq "pbcopy") {
	local $/;
	$data = <>;
	use bytes;
	$size = length $data;
}

my $secret = do {
	local $/;
	open my $fh, "<", "$ENV{HOME}/.copy_paste_secret" or die $!;
	<$fh>;
};

my $sock = IO::Socket::INET->new(
	PeerAddr => 'localhost',
	PeerPort => 5313,
	Proto => 'tcp',
) or die "could not connect: $!\n";


my $token = encode_jwt(
	alg          => 'PBES2-HS256+A128KW',
	enc          => 'A128GCM',
	key          => $secret,
	relative_exp => 2,
	payload      => {
		cmd => $cmd,
		data => $data,
	},
);

print $sock "$token\r\n";

(my $res_token = <$sock>) =~ s/\r\n//;

my $res = eval { decode_jwt(token => $res_token, key => $secret) };

unless ($res and not $res->{error}) {
	# do fuck all
	# if this actually becomes an issue, maybe print to STDERR
	return;
}

# if doing a copy, who cares about the return token
if ($cmd eq 'pbpaste') {
	print $res->{paste};
	
	if ($force_newline and $res->{paste} !~ /\n$/) {
		print "\n";
	}
}
