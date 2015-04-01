#!/usr/bin/perl

use warnings;
use strict 'vars';
use NetCDF;

my $l_file;
my $l_varId;
my $l_name;
my $l_dimCount;
my @l_dimIds;
my $l_atts;
my $l_size;
my @l_fileValues;
my $l_datatype;

$l_file = NetCDF::open("AR_LATEST_PR_CT_MYO_AR_58AA_20110519.nc", NOWRITE);
$l_file >= 0 || die "open() failue";
                
$l_varId = NetCDF::varid($l_file, "LONGITUDE");
$l_varId >= 0 || die "varid() failure";

NetCDF::varinq($l_file, $l_varId, \$l_name, \$l_datatype, \$l_dimCount,
        \@l_dimIds, \$l_atts) == 0 || die "varinq() failure";

NetCDF::diminq($l_file, $l_dimIds[0], \$l_name, \$l_size) == 0 ||
        die "diminq() failure";
NetCDF::varget($l_file, $l_varId, [0], [$l_size], \@l_fileValues) == 0 ||
        die "varget() failure";

foreach my $l_value (@l_fileValues) {
    print "$l_value, Value $l_fileValues[$l_value]\n";
}
