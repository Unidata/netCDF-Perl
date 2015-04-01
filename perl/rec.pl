#!/usr/local/bin/perl

use NetCDF;


#
# Create netCDF file.
#
print STDERR "Creating netCDF file...........................";
$ncid = NetCDF::create("rec.nc", NetCDF::CLOBBER);
die "Couldn't open netCDF file\n" if $ncid < 0;
print STDERR "ok\n";


#
# Set fill mode.
#
print STDERR "Setting fill mode..............................";
NetCDF::setfill($ncid, NetCDF::NOFILL) == 0 ||
    die "Couldn't set fill mode\n";
print STDERR "ok\n";


#
# Define record dimension.
#
print STDERR "Defining record dimension......................";
$recdimid = NetCDF::dimdef($ncid, "recdim", UNLIMITED);
die "Couldn't define record dimension\n" if $recdimid < 0;
print STDERR "ok\n";


#
# Define record variables.
#
print STDERR "Defining record variables......................";
$recvar0id = NetCDF::vardef($ncid, "recvar0", NetCDF::SHORT, 
			     [$recdimid]);
die "Couldn't define first record variable\n" if $recvar0id < 0;

$recvar1id = NetCDF::vardef($ncid, "recvar1", NetCDF::FLOAT, 
			     [$recdimid]);
die "Couldn't define second record variable\n" if $recvar1id < 0;
print STDERR "ok\n";


#
# End definition.
#
print STDERR "Ending definition..............................";
$status = NetCDF::endef($ncid);
die "Couldn't end definition\n" if $status < 0;
print STDERR "ok\n";


#
# Synchronize netCDF file.
#
print "Synchronizing netCDF I/O.......................";
$status = NetCDF::sync($ncid);
die "Couldn't synchronize netCDF file\n" if $status < 0;
print "ok\n";


#
# Write values to record variables.
#
print STDERR "Writing record values..........................";
$recvar0 = 10;
$recvar1 = 20;
$status = NetCDF::recput($ncid, 0, [\$recvar0, \$recvar1]);
die "Couldn't write to record variables\n" if $status < 0;
$recvar0 = 11;
$recvar1 = 21;
$status = NetCDF::recput($ncid, 1, [\$recvar0, \$recvar1]);
die "Couldn't write to record variables\n" if $status < 0;
print STDERR "ok\n";


#
# Close netCDF file.
#
print STDERR "Closing netCDF file............................";
$status = NetCDF::close($ncid);
die "Couldn't close netCDF file\n" if $status < 0;
print STDERR "ok\n";


#
# Reopen netCDF file.
#
print STDERR "Reopening netCDF file..........................";
$ncid = NetCDF::open("rec.nc", NetCDF::NOWRITE);
die "Couldn't open netCDF file\n" if $ncid < 0;
print STDERR "ok\n";


#
# Read values from record variables.
#
#print STDERR "Reading record values..........................";
#$ref = [\@var0, \@var1];
#$status = NetCDF::recget($ncid, 0, $ref);
$status = NetCDF::recget($ncid, 1, [\@var0, \@var1]);
#$var0ref = \@var0;
#$var1ref = \@var1;
#$status = NetCDF::recget($ncid, 0, [$var0ref, $var1ref]);
#$ref = [$var0ref, $var1ref];
#$status = NetCDF::recget($ncid, 0, $ref);
#die "Couldn't read from record variables\n" if $status < 0;
#if ($var0[0] != 11 || $var1[0] != 21)
#{
#    print STDERR "variable 0 = $var0[0]\n";
#    print STDERR "variable 1 = $var1[0]\n";
#    die "Incorrect record values\n";
#}
#print STDERR "ok\n";


##
## Read values from record variables.
##
#print STDERR "Reading record values..........................";
#@record = ();
#$status = NetCDF::recget($ncid, 0, \@record);
#die "Couldn't read from record variables\n" if $status < 0;
#$nv = @record;
#$nv == 2 || die "Incorrect number of record variables: $nv != 2\n";
#$var0ref = $record[0];
#$var1ref = $record[1];
#if ($$var0ref[0] != 0 || $$var1ref[0] != 1)
#{
#    print STDERR "variable 0 = $$var0ref[0]\n";
#    print STDERR "variable 1 = $$var1ref[0]\n";
#    die "Incorrect record values\n";
#}
#print STDERR "ok\n";


#
# Read values from record variables.
#
#print STDERR "Reading record values..........................";
#$status = NetCDF::recget($ncid, 0, [\$var0, \$var1]);
#die "Couldn't read from record variables\n" if $status < 0;
#if ($var0 != 0 || $var1 != 1)
#{
#    print STDERR "variable 0 = $var0\n";
#    print STDERR "variable 1 = $var1\n";
#    die "Incorrect record values\n";
#}
#print STDERR "ok\n";


#
# Write new values to record variables.
#
print STDERR "Writing record values..........................";
$recvar0 = 100;
$recvar1 = 200;
$status = NetCDF::recput($ncid, 0, [\$recvar0, \$recvar1]);
die "Couldn't write to record variables\n" if $status < 0;
$recvar0 = 110;
$recvar1 = 210;
$status = NetCDF::recput($ncid, 1, [\$recvar0, \$recvar1]);
die "Couldn't write to record variables\n" if $status < 0;
print STDERR "ok\n";


#
# Close netCDF file.
#
print STDERR "Closing netCDF file............................";
$status = NetCDF::close($ncid);
die "Couldn't close netCDF file\n" if $status < 0;
print STDERR "ok\n";
