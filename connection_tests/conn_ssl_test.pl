#!/usr/bin/perl
 
use DBI;
use Time::HiRes qw(time);
 
$start = time;
for (my $i=0; $i<1000; $i++) {
  my $dbh = DBI->connect("dbi:mysql:host=10.189.226.47;port=3306;mysql_ssl=1;mysql_ssl_ca_file=../ca-cert.pem",
                         "dbaasdbusr","neingaengeetaenoothieyahziegheij",undef);
  $dbh->disconnect;
  undef $dbh;
}
printf "%.6fn", time - $start;
printf "\n";
