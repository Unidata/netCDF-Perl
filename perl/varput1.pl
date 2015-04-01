#!/usr/local/bin/perl -w

use NetCDF;


# Open netCDF dataset.
#
$ncid=NetCDF::open("varput1.nc",NetCDF::WRITE);


# Get variable ID.
#
$varid=NetCDF::varid($ncid,"TMax");


# Write new value.
#
@start = (0,0,0);
$in = 20;
$stats = NetCDF::varput1($ncid,$varid,\@start,$in);


# Read new value.
#
$out = 0;
$stats = NetCDF::varget1($ncid,$varid,\@start,$out);


# Print.
#
printf("In Value: %s  netCDF Value: %s\n",$in,$out);


# Close netCDF dataset.
#
NetCDF::close($ncid);
