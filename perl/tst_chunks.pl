use NetCDF;

#
# Open netCDF file.
#
print "Opening netCDF file for reading\n";
$ncid = NetCDF::open("tst_chunks.nc", NetCDF::NOWRITE);
die "Couldn't open netCDF file\n" if $ncid < 0;

#
# Inquire about netCDF file.
#
print "Inquiring about netCDF file\n";
$status = NetCDF::inquire($ncid, $nd, $nv, $na, $dimid);
die "Couldn't inquire about netCDF file\n" if $status < 0;

print "nd: $nd  nv: $nv  na: $na  dimid: $dimid\n";

#
# Check the value of a variable element.
#
print "Checking variable value: ";
@start = (1, 2, 3);
@count = (1, 1, 1);
@values = ();
$status = NetCDF::varget($ncid, 0, \@start, \@count, \@values);
($status == 0) || die "Couldn't read from fixed variable\n";
$values[0] == 92 || die "value not 92: $values[0]\n"; 
print "correct\n";

NetCDF::close($ncid) == 0 || die "Couldn't close netCDF file\n";
