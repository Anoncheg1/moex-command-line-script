#!/usr/bin/env perl
use strict; # ограничить применение небезопасных конструкций
use warnings; # выводить подробные предупреждения компилятора
use diagnostics; # выводить подробную диагностику ошибок
no warnings "experimental::autoderef"; #keys
use LWP::UserAgent;
require HTTP::Response;
use HTML::TreeBuilder;
use JSON;
use Getopt::Std;
use Clone 'clone';
use Data::Dumper;
#use Getopt::Std;
#Debian: liblwp-protocol-socks-perl
use LWP::Protocol::socks;


package main;


sub printIColumn($@){ #$ - json, @ - array of columns - ("LAST", "FIRST")
	#print Dumper($_[0]);
	print "error in instrument","\n" and exit 1 if !$_[0]->{'data'}[0];
	my $size = @{$_[1]};
	my $col = $_[0]->{'columns'};
	my @colNum = (1 .. $size); #inicialization of array
	for (my $i = 0; $i < @{$col}; $i++){
		for (my $j = 0; $j < $size; $j++){
			$colNum[$j] = $i if ($col->[$i] eq $_[1][$j]);
		}
	}
	for (my $j = 0; $j < $size; $j++){
		my $n = $colNum[$j];
		print $_[0]->{'data'}[0][$n],"\n";
	}
}

#return column number
sub getSColumn($$){ # $ - json, $ - column name
	print "error in instrument","\n" and exit 1 if !$_[0];
	for (my $i = 0; $i < @{$_[0]}; $i++){
		if ($_[0][$i] eq $_[1]){
			return $i;
		}
	}
}



my $ua = LWP::UserAgent->new; #параметры подключения
$ua->agent("Mozilla/5.0 (Windows NT 5.1; rv:5.0.1) Gecko/20100101 Firefox/5.0.1");
my @PROXY;
#@PROXY =([qw(http https)] => "socks://172.16.0.1:9150"); #tor
#@PROXY = ('http','http://127.0.0.1:4444'); #i2p
$ua->proxy(@PROXY) if @PROXY;

my %opt =();
getopts( ":lds", \%opt ) or print STDERR "Usage: -l -d \nreference http://moex.com/iss/reference/\n" and exit 1;

#search for index
my $request = join(" ", @ARGV);
$request =~ s/^\s+//g; #trim front
$request = uc $request;
my $uaS = clone($ua);
my $url="http://www.micex.ru/iss/securities.json?q=$request";#&iss.json=extended";
#print $url;
my $req = HTTP::Request->new(GET => $url);
my $res;
	$res = $uaS->request($req);
	$res = $uaS->request($req) if (! $res->is_success); #resent
if (!$res->is_success){
	print (($res->status_line)." Can't connect for search.\n") and exit 1;
}
#print $res->decoded_content;
my $js = $res->decoded_content;
#my $enable = 1;
my $json = JSON->new->property("canonical" => 1); #sorted hash
my $jarr = $json->decode($js);
#print Dumper($jarr->{"securities"});
if (!$jarr->{"securities"}->{"data"}[0]){
	print "Instrument not found","\n" and exit 1; 
}
if (defined $opt{s}){
	for (my $i = 0; $i < @{$jarr->{"securities"}->{"data"}}; $i++){
		for (my $j = 0; $j < 0+@{$jarr->{"securities"}->{"data"}[$i]};$j++){
			my $d = $jarr->{"securities"}->{"data"}[$i][$j];
			print $d," " if defined $d;
		}
		print "\n";
	}
	exit 0;
}
my $secid_n = getSColumn($jarr->{"securities"}->{"columns"}, "secid");
my $b_n = getSColumn($jarr->{"securities"}->{"columns"}, "primary_boardid");
my $shortname_n = getSColumn($jarr->{"securities"}->{"columns"}, "shortname");
my $name_n = getSColumn($jarr->{"securities"}->{"columns"}, "name");

my $instr = $jarr->{"securities"}->{"data"}[0][$secid_n];
my $board = $jarr->{"securities"}->{"data"}[0][$b_n];
my $name = $jarr->{"securities"}->{"data"}[0][$name_n]; #just name
#print "size=".@{$jarr->{"securities"}->{"data"}->[0]},"\n";
for (my $i = 0; $i < @{$jarr->{"securities"}->{"data"}}; $i++){
	my $in = $jarr->{"securities"}->{"data"}[$i];
	if ($in->[$shortname_n] =~ /$request/i or $in->[$secid_n] =~ /$request/i){  #we search in short names
		$instr = $in->[$secid_n];
		$board = $in->[$b_n];
		$name = $in->[$name_n];
	
		if ($in->[$shortname_n] eq $request){
			$instr = $in->[$secid_n];
			$board = $in->[$b_n];
			$name = $in->[$name_n];
			last;
		}
	}
}
#print getSColumn($jarr->{"securities"}->{"metadata"}, "id"),"\n";
print $instr,"\t",$name,"\t",$board,"\n";
#print $group,"\n";

while(1){
	my $uaLoop = clone($ua);
	my $url="http://www.moex.com/iss/engines/stock/markets/shares/boards/$board/securities/$instr.jsonp";
	#print $url,"\n";
	my $req2 = HTTP::Request->new(GET => $url);
	my $response;
		$response = $uaLoop->request($req2);
		$response = $uaLoop->request($req2) if (! $response->is_success); #resent
	#print $response->decoded_content;
	if ($response->is_success){
		my $js2 = $response->decoded_content;
		my $jarray =  JSON->new->decode($js2);
		if (defined $opt{l}){
			print Dumper($jarray->{'marketdata'}->{'columns'});
		}
		if (defined $opt{d}){
			print Dumper($jarray->{'marketdata'}->{'data'});
		}
	
		my @c = ("OPEN", "LAST", "SYSTIME");
		printIColumn($jarray->{'marketdata'}, \@c);
		

	}else{ print (($response->status_line)." Can't connect.\n") and exit 0};
	sleep 5;#sec

}