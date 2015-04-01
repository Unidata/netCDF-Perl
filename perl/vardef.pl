#!/usr/local/bin/perl -w

use NetCDF;


# Open netCDF dataset.
#
$ncid=NetCDF::create("vardef.nc",NetCDF::WRITE);


# Create scalar variable.
#
NetCDF::vardef($ncid, "scalar", NetCDF::FLOAT, []);


# Close netCDF dataset.
#
NetCDF::close($ncid);
