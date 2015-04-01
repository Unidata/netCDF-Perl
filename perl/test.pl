#!/usr/local/bin/perl

use warnings;
use strict 'vars';
use NetCDF;


#@a=(1,2);
#NetCDF::foo(\@a);


my $pathname = "foo.nc";
my $dim0name = "dim0";
my $dim1name = "dim1";
my $scalarvarname = "scalarvar";
my $fixvarname = "fixvar";
my $ndims = 4;
my $nvars = 5;
my $nrecvar = 3;
my $nregrecvar = 2;
my $natts = 0;
my @dimlen = (2, 3);
my $dimstrlen = 12;
my $dimstrname = "strlen";
my $scalarvarvalue = 5.5;

my $attid;
my $attval;
my $dim0id;
my $dim0len;
my $dim1id;
my $dim1len;
my $dimid;
my $dimstrid;
my $scalarvarid;
my $scalarvartype;
my $fixvarid;
my $fixvarnatts;
my $fixvarndims;
my $fixvartype;
my $globattname;
my $histatt;
my $i;
my $idim;
my $j;
my $len;
my $length;
my $na;
my $name;
my $ncid;
my $nd;
my $nrecvars;
my $nv;
my $recdimid;
my $recvar0id;
my $recvar1id;
my $recvars;
my $recvarstrid;
my $status;
my $type;
my $value;
my $varid;
my $varref;
my @atts;
my @coords;
my @dimids;
my @counts;
my @scalarvarcount;
my @fixvarcount;
my @fixvardimids;
my @fixvarstart;
my @fixvarvalue;
my @record;
my @recsizes;
my @recvar0;
my @recvar1;
my @recvarids;
my @recvars;
my @values;


#
# Create netCDF file.
#
print STDERR "Creating netCDF file...........................";
$ncid = NetCDF::create($pathname, NetCDF::CLOBBER);
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
# Define scalar variable.
#
print STDERR "Defining scalar variable.......................";
$scalarvartype = NetCDF::FLOAT;
@dimids = ();
$scalarvarid = NetCDF::vardef($ncid, $scalarvarname, $scalarvartype, \@dimids);
die "Couldn't define scalar variable\n" if $scalarvarid < 0;
print STDERR "ok\n";


#
# Define fixed dimensions.
#
print STDERR "Defining fixed dimensions......................";
$dim0len = $dimlen[0];
$dim0id = NetCDF::dimdef($ncid, $dim0name, $dim0len);
die "Couldn't define first dimension\n" if $dim0id < 0;
print STDERR "ok\n";

@dimids = ( $dim0id );

$dim1len = $dimlen[1];
$dim1id = NetCDF::dimdef($ncid, $dim1name, $dim1len);
die "Couldn't define second dimension\n" if $dim1id < 0;

push(@dimids, $dim1id);

$dimstrid = NetCDF::dimdef($ncid, $dimstrname, $dimstrlen);
die "Couldn't define string dimension\n" if $dimstrid < 0;


#
# Define fixed variables.
#
print STDERR "Defining fixed variables.......................";
$fixvartype = NetCDF::FLOAT;
$fixvarndims = @dimids;
$fixvarid = NetCDF::vardef($ncid, $fixvarname, $fixvartype, \@dimids);
die "Couldn't define fixed variable\n" if $fixvarid < 0;
@fixvardimids = @dimids;
print STDERR "ok\n";


#
# Put global attribute.
#
print STDERR "Writing global attribute.......................";
$globattname = "history";
$histatt = "Created by $0 on " . localtime();
$attid = NetCDF::attput($ncid, NetCDF::GLOBAL, $globattname, NetCDF::CHAR,
			$histatt);
$attid != -1 || die "Couldn't write global attribute\n";
print STDERR "ok\n";


#
# Put variable attributes.
#
print STDERR "Writing variable attributes....................";
@atts = (255, -128);
$attid = NetCDF::attput($ncid, $fixvarid, "att_byte", NetCDF::BYTE,
			  \@atts);
die "Couldn't put byte attribute\n" if $attid < 0;

$attid = NetCDF::attput($ncid, $fixvarid, "att_char", NetCDF::CHAR,
			  "string");
die "Couldn't put char attribute\n" if $attid < 0;

@atts = (5, 6, 7);
$attid = NetCDF::attput($ncid, $fixvarid, "att_short", NetCDF::SHORT,
			  \@atts);
die "Couldn't put short attribute\n" if $attid < 0;

@atts = (3, 4);
$attid = NetCDF::attput($ncid, $fixvarid, "att_long", NetCDF::LONG,
			  \@atts);
die "Couldn't put long attribute\n" if $attid < 0;

$attid = NetCDF::attput($ncid, $fixvarid, "att_float", NetCDF::FLOAT, 
			  2.7182818);
die "Couldn't put float attribute\n" if $attid < 0;

@atts = (2.7182818, 3.1415927);
$attid = NetCDF::attput($ncid, $fixvarid, "att_double", NetCDF::DOUBLE, 
			  \@atts);
die "Couldn't put double attribute\n" if $attid < 0;
print STDERR "ok\n";

$fixvarnatts = 6;


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
			     [$recdimid, $dim0id]);
die "Couldn't define first record variable\n" if $recvar0id < 0;

$recvar1id = NetCDF::vardef($ncid, "recvar1", NetCDF::FLOAT, 
			     [$recdimid, $dim1id]);
die "Couldn't define second record variable\n" if $recvar1id < 0;

$recvarstrid = NetCDF::vardef($ncid, "recvarstr", NetCDF::CHAR, 
			     [$recdimid, $dimstrid]);
die "Couldn't define string record variable\n" if $recvarstrid < 0;

print STDERR "ok\n";


#
# End definition.
#
print STDERR "Ending definition..............................";
$status = NetCDF::endef($ncid);
die "Couldn't end definition\n" if $status < 0;
print STDERR "ok\n";


#
# Write value of scalar variable.
#
print STDERR "Writing scalar variable value..................";
@coords = ();
@counts = (1);
$status = NetCDF::varput($ncid, $scalarvarid, \@coords, \@counts,
			   $scalarvarvalue);
die "Couldn't write scalar-variable\n" if $status < 0;
print STDERR "ok\n";


#
# Write values to fixed variable.
#
print STDERR "Writing fixed variable values..................";
@fixvarstart = (0, 1);
@fixvarcount = (2, 1);
@fixvarvalue = (998, 999);
$status = NetCDF::varput($ncid, $fixvarid, \@fixvarstart, \@fixvarcount,
			   \@fixvarvalue);
die "Couldn't write fixed-variable\n" if $status < 0;
print STDERR "ok\n";

##@arg = ();
#$argref = [];
#$status = foo($argref);
#print STDERR "foo() = $status\n";
#print STDERR "argref = @$argref\n";
##print STDERR "arg = @arg\n";


#
# Synchronize netCDF file.
#
print STDERR "Synchronizing netCDF I/O.......................";
$status = NetCDF::sync($ncid);
die "Couldn't synchronize netCDF file\n" if $status < 0;
print STDERR "ok\n";


#
# Write values to record variables.
#
print STDERR "Writing record values..........................";
@recvar0 = (101 .. (100+$dim0len));
@recvar1 = (201 .. (200+$dim1len));
$status = NetCDF::recput($ncid, 0, [\@recvar0, \@recvar1, \"hello world\0"]);
die "Couldn't write to record variables\n" if $status < 0;
print STDERR "ok\n";


#
# Save the values of the record variables.
#
$recvars = [ \@recvar0, \@recvar1 ];


#
# Close netCDF file.
#
print STDERR "Closing netCDF file............................";
$status = NetCDF::close($ncid);
die "Couldn't close netCDF file\n" if $status < 0;
print STDERR "ok\n";


#
# Open netCDF file.
#
print STDERR "Opening netCDF file for reading................";
$ncid = NetCDF::open($pathname, NOWRITE);
die "Couldn't open netCDF file\n" if $status < 0;
print STDERR "ok\n";


#
# Inquire about netCDF file.
#
print STDERR "Inquiring about netCDF file....................";
$status = NetCDF::inquire($ncid, $nd, $nv, $na, $dimid);
die "Couldn't inquire about netCDF file\n" if $status < 0;
die "Incorrect netCDF information\n" if $nd != $ndims;
die "Incorrect netCDF information\n" if $nv != $nvars;
die "Incorrect netCDF information\n" if $dimid != $recdimid;

#die "Incorrect netCDF information\n" if $nd != $ndims ||
#					$nv != $nvars ||
#					$na != 1 ||
#					$dimid != $recdimid;
print STDERR "ok\n";


#
# Get global attribute.
#
print STDERR "Checking global attribute name.................";
NetCDF::attname($ncid, NetCDF::GLOBAL, 0, $name) == 0 ||
    die "Couldn't get global attribute name\n";
($name eq $globattname) ||
    die "Incorrect global attribute name: \"$name\" != \"$globattname\"\n";
print STDERR "ok\n";
print STDERR "Checking global attribute value................";
$attval = "";
NetCDF::attget($ncid, NetCDF::GLOBAL, "history", \$attval) == 0 ||
    die "Couldn't get fixed variable attribute\n";
$attval =~ /$histatt/ || 
    die "Incorrect global attribute value: \"$attval\"\n";
print STDERR "ok\n";

#
# Vet scalar variable.
#
print STDERR "Checking scalar variable.......................";
NetCDF::varinq($ncid, $scalarvarid, $name, $type, $ndims, \@dimids, $natts)
    == 0 || die "Couldn't get information on scalar variable\n";
if ($name ne $scalarvarname ||
    $type != $scalarvartype ||
    $ndims != 0 ||
    $natts != 0)
{
    die "Incorrect fixed variable information\n";
}
@coords = ();
@counts = ();
@values = ();
NetCDF::varget($ncid, $scalarvarid, \@coords, \@counts, \@values) == 0 ||
    die "Couldn't get value of scalar variable\n";
$values[0] == $scalarvarvalue ||
    die "Incorrect value for scalar variable\n";
print STDERR "ok\n";



#
# Get ID of second dimension.
#
print STDERR "Getting second dimension ID....................";
$dimid = NetCDF::dimid($ncid, $dim1name);
die "Incorrect second dimension ID\n" if $dimid != $dim1id;
print STDERR "ok\n";


#
# Vet second dimension information.
#
print STDERR "Checking second dimension information..........";
NetCDF::diminq($ncid, $dim1id, $name, $length) == 0 ||
    die "Couldn't get information on second dimension\n";
($name eq $dim1name) || 
    die "Incorrect second dimension name: \"$name\" != \"$dim1name\"\n";
($length == $dim1len) ||
    die "Incorrect second dimension length: $length != $dim1len\n";
print STDERR "ok\n";


#
# Vet variable ID of fixed variable.
#
print STDERR "Checking fixed variable ID.....................";
$varid = NetCDF::varid($ncid, $fixvarname);
($varid >= 0) || die "Couldn't get variable ID of fixed variable\n";
($varid == $fixvarid) || die "Incorrect fixed variable ID: ",
			     "$varid != $fixvarid\n";
print STDERR "ok\n";


#
# Vet information on fixed variable.
#
printf STDERR "Checking fixed variable information............";
@dimids = ();
NetCDF::varinq($ncid, $fixvarid, $name, $type, $ndims, \@dimids, $natts)
    == 0 || die "Couldn't get information on fixed variable\n";
if ($name ne $fixvarname ||
    $type != $fixvartype ||
    $ndims != $fixvarndims ||
    $natts != $fixvarnatts)
{
    die "Incorrect fixed variable information\n";
}
for ($idim = 0; $idim < $ndims; $idim++)
{
    ($dimids[$idim] == $fixvardimids[$idim]) ||
	die "Incorrect dimension $idim ID: ",
	    "$dimids[$idim] != $fixvardimids[$idim]\n";
}
print STDERR "ok\n";


#
# Vet last value of first record variable.
#
#
# For some reason, the following assignment results in a segmentation
# violation in the "varget1" statement unless the "print" statement is enabled
# when being interpreted by perl v5.8.0 (earlier version worked OK).
#
# @coords = (0, $#recvar0);
# print STDERR "ncid=$ncid; recvar0id=$recvar0id; coords=(@coords)\n";
#
# Hence, we use this equivalent assignment, instead.
#
@coords = (0, scalar(@recvar0)-1);
print STDERR "Checking last value of first record variable...";
NetCDF::varget1($ncid, $recvar0id, \@coords, $value) == 0 ||
    die "Couldn't get last value of first record variable\n";
$value == $recvar0[$#recvar0] ||
    die "Incorrect last value of first record variable: ",
	"$value != $recvar0[$#recvar0]\n";
print STDERR "ok\n";


#
# Vet fixed variable values.
#
print STDERR "Reading fixed variable values..................";
@values = ();
$status = NetCDF::varget($ncid, $varid, \@fixvarstart, \@fixvarcount,
			   \@values);
($status == 0) || die "Couldn't read from fixed variable\n";
if (@fixvarvalue != @values)
{
    die "Incorrect vector size\n";
}
else
{
    for ($i = 0; $i < @fixvarvalue; $i++)
    {
	$fixvarvalue[$i] == $values[$i] ||
	    die "Incorrect fixed value $i: ",
		"$fixvarvalue[$i] != $values[$i]\n";
    }
}
print STDERR "ok\n";


#
# Vet fixed variable attributes.
#
print STDERR "Reading fixed variable attributes..............";
NetCDF::attname($ncid, $fixvarid, 0, $name) == 0 ||
    die "Couldn't get attribute name\n";
$name eq "att_byte" || die "Incorrect attribute name: \"$name\"\n";
NetCDF::attinq($ncid, $fixvarid, "att_float", $type, $len) == 0 ||
    die "Couldn't get information on fixed variable attribute\n";
$type == NetCDF::FLOAT || die "Incorrect attribute type\n";
$len == 1 || die "Incorrect attribute length\n";
@values = ();
NetCDF::attget($ncid, $fixvarid, "att_float", \@values) == 0 ||
    die "Couldn't get fixed variable attribute\n";
abs(($values[0] - 2.7182818) / 2.7182818) < .000001 || 
    die "Incorrect attribute value: $values[0]\n";
print STDERR "ok\n";


#
# Vet NetCDF::typelen().
#
print STDERR "Checking typelen().............................";
NetCDF::typelen(NetCDF::FLOAT) == 4 || die "Incorrect float length\n";
print STDERR "ok\n";


#
# Inquire about record variables.
#
@recvarids = ();
@recsizes = ();
NetCDF::recinq($ncid, $nrecvars, \@recvarids, \@recsizes) == 0 ||
    die "Couldn't inquire about record variables\n";
print STDERR "Checking number of record variables............";
$nrecvars == $nrecvar || die "Incorrect number of record variables: ",
			     "$nrecvars != $nrecvar\n";
print STDERR "ok\n";
print STDERR "Checking variable IDs..........................";
($recvarids[0] == $recvar0id && $recvarids[1] == $recvar1id) ||
    die "Incorrect record variable IDs: ",
	"($recvarids[0],$recvarids[1]) != ($recvar0id,$recvar1id)\n";
print STDERR "ok\n";
print STDERR "Checking variable sizes........................";
$recsizes[0] == $dim0len * NetCDF::typelen(NetCDF::SHORT) &&
    $recsizes[1] == $dim1len * NetCDF::typelen(NetCDF::FLOAT) ||
    die "Incorrect record variable sizes\n";
print STDERR "ok\n";

#
# Read values of record variables.
#
print STDERR "Reading values of record variables.............";
@record = ();
$status = NetCDF::recget($ncid, 0, \@record);
($status >= 0) || die "Couldn't read record\n";
$nv = @record;
$nv == $nrecvar ||
    die "Incorrect number of record variables: $nv != $nrecvar\n";
for ($i = 0; $i < $nregrecvar; $i++)
{
    $varref = $record[$i];
    (@$varref == $dimlen[$i]) || 
	die "Incorrect number of elements in record variable $i: ",
	    "@$varref != $dimlen[$i]\n";
    for ($j = 0; $j < $dimlen[$i]; $j++)
    {
	($$varref[$j] == $$recvars[$i][$j]) ||
	    die "Incorrect record variable value: ",
		"$$varref[$j] != $recvars[$i][$j]\n";
    }
}
${$record[2]} =~ /hello world/ || 
    die "Incorrect record string-variable\n";
print STDERR "ok\n";


print STDERR "Closing netCDF file............................";
NetCDF::close($ncid) == 0 || die "Couldn't close netCDF file\n";
print STDERR "ok\n";
