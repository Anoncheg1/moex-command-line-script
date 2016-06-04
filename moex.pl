#!/usr/bin/env perl
use strict; # ограничить применение небезопасных конструкций
use warnings; # выводить подробные предупреждения компилятора
use diagnostics; # выводить подробную диагностику ошибок
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


my $ua = LWP::UserAgent->new; #параметры подключения
$ua->agent("Mozilla/5.0 (Windows NT 5.1; rv:5.0.1) Gecko/20100101 Firefox/5.0.1");
my @PROXY;
#@PROXY =([qw(http https)] => "socks://172.16.0.1:9150"); #tor
#@PROXY = ('http','http://127.0.0.1:4444'); #i2p
$ua->proxy(@PROXY) if @PROXY;

my %opt =();
getopts( ":ld", \%opt ) or print STDERR "Usage: -l -d \nreference http://moex.com/iss/reference/\n" and exit 1;

#search for index
my $request = join(" ", @ARGV);
$request =~ s/^\s+//g; #trim front
$request = uc $request;
my $uaS = clone($ua);
my $url="http://www.micex.ru/iss/securities.json?q=".$request;
#print $url;
my $req = HTTP::Request->new(GET => $url);
my $res;
	$res = $uaS->request($req);
	$res = $uaS->request($req) if (! $res->is_success); #resent
#print $res->decoded_content;
my $js = $res->decoded_content;
my $jarr =  JSON->new->decode($js);
if (!$jarr->{"securities"}->{"data"}[0]){
	print "Instrument not found","\n" and exit 1; 
}
my $instr = $jarr->{"securities"}->{"data"}[0][1];
my $group = $jarr->{"securities"}->{"data"}[0][14]; #group
my $name = $jarr->{"securities"}->{"data"}[0][4]; #just name
#print "size=".@{$jarr->{"securities"}->{"data"}->[0]},"\n";
for (my $i = 0; $i < @{$jarr->{"securities"}->{"data"}}; $i++){
	my $in = $jarr->{"securities"}->{"data"}[$i];
	if ($in->[1] eq $request){
		
		$instr = $in->[1];
		$group = $in->[14];
		
		}
}
print $instr,"\t",$name,"\t",$group,"\n";
#print $_," " foreach $jarr->{"securities"}->{"data"}[0];
if (!$res->is_success){
	print (($res->status_line)." Can't connect for search.\n") and exit 1;
}

while(1){
	my $uaLoop = clone($ua);
	my $url="http://www.moex.com/iss/engines/stock/markets/shares/boards/$group/securities/$instr.jsonp";
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


		my $col = $jarray->{'marketdata'}->{'columns'};
		my $id_open;
		my $id_last;
		my $id_st;
		for (my $i = 0; $i < @{$col}; $i++){
			$id_open = $i if ($col->[$i] eq "OPEN");
			$id_last = $i if ($col->[$i] eq "LAST");
			$id_st = $i if ($col->[$i] eq "SYSTIME");
		}
		print "error in instrument","\n" and exit 1 if !$jarray->{'marketdata'}->{'data'}[0];
		#my $size = @{$jarray->{'marketdata'}->{'data'}[0]};
		#if($id_open < $size && $id_last < $size && $id_st < $size){
		#print $id_open, " ", $id_last," ", $id_st;
			print $jarray->{'marketdata'}->{'data'}[0][$id_open],"\n";
			print $jarray->{'marketdata'}->{'data'}[0][$id_last],"\n";
			print $jarray->{'marketdata'}->{'data'}[0][$id_st],"\n";
		#}else{print "error in instrument" and exit 1;}

	}else{ print (($response->status_line)." Can't connect.\n") and exit 0};
	sleep 5;#sec

}