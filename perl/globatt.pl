use NetCDF;

$ncfile = shift(@ARGV);

#
# Open netCDF file.
#
print "Opening netCDF file for reading\n";
$ncid = NetCDF::open($ncfile, NetCDF::NOWRITE);
die "Couldn't open netCDF file\n" if $ncid < 0;

#
# Inquire about netCDF file.
#
print "Inquiring about netCDF file\n";
$status = NetCDF::inquire($ncid, $nd, $nv, $na, $dimid);
die "Couldn't inquire about netCDF file\n" if $status < 0;

print "nd: $nd  nv: $nv  na: $na  dimid: $dimid\n";

#
# Get all Global attribute names, this only gets the first one
#
print "\nAttribute Names:\n";
$n = 0;
while ($n < $na) {
    $name = '';
    $status = NetCDF::attname($ncid, NetCDF::GLOBAL, $n, $name);
    print "$status  $n  $name\n";
    $n++;
}

NetCDF::close($ncid) == 0 || die "Couldn't close netCDF file\n";
