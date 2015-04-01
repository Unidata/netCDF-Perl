#!/usr/local/bin/perl
##!/data/zender/bin/SUNMP/perl -w

use NetCDF;

# Set output flushing to help debugging on hard crashes. 
# These options update the filehandle after every output statement.
# See the camel book, p. 110.
select((select(STDOUT),$|=1)[0]);
select((select(STDERR),$|=1)[0]);

$out_file='foo.nc';

# Dimensions
%dim_cnt=(
	  'wv_nbr',NetCDF::UNLIMITED,
	  );

# Variables
%var_dim=(
		'HWHM','wv_nbr',
		'HWHM_t_dep','wv_nbr',
		'iso_nbr','scalar',
		'ln_str','wv_nbr',
		'mlc_nbr','scalar',
		'nrg_lo','wv_nbr',
		'wv_nbr','wv_nbr',
		);
%var_type=(
		'HWHM',NetCDF::FLOAT,
		'HWHM_t_dep',NetCDF::FLOAT,
		'iso_nbr',NetCDF::SHORT,
		'ln_str',NetCDF::FLOAT,
		'mlc_nbr',NetCDF::SHORT,
		'nrg_lo',NetCDF::FLOAT,
		'wv_nbr',NetCDF::FLOAT,
		);

# Create netCDF output file
print STDOUT 'Creating netCDF file...';
$nc_id=NetCDF::create($out_file,NetCDF::CLOBBER);
die "Could not open netCDF file\n" if $nc_id < 0;
print STDOUT "ok\n";

# Set fill mode
print STDOUT 'Setting fill mode...';
NetCDF::setfill($nc_id,NetCDF::NOFILL) == 0 || die "Could not set fill mode\n";
print STDOUT "ok\n";

# Define dimensions
print STDOUT 'Defining dimensions...';
foreach $dim_nm (keys(%dim_cnt)){
    $dim_id{$dim_nm}=NetCDF::dimdef($nc_id,$dim_nm,$dim_cnt{$dim_nm});
    die "Could not define dimension\n" if $dim_id{$dim_nm} < 0;
} # end loop over dimensions
print STDOUT "ok\n";

# Now that we have the dimension IDs, form the dimension ID vectors
@scalar=();
%dim_vec=(
	  'scalar',\@scalar,
	  'wv_nbr',$dim_id{'wv_nbr'},
	  );

# Define variables
print STDOUT 'Defining variables...';
foreach $var_nm (sort keys(%var_dim)){

    $var_id{$var_nm}=NetCDF::vardef($nc_id,$var_nm,$var_type{$var_nm},\$dim_vec{$var_dim{$var_nm}});
    die "Could not define variable\n" if $var_id{$var_nm} < 0;

} # end loop over variables
print STDOUT "ok\n";

# End definition
print STDOUT 'Ending definition mode...';
$status=NetCDF::endef($nc_id);
die "Could not end definition mode\n" if $status < 0;
print STDOUT "ok\n";

# Close netCDF file
print STDOUT 'Closing netCDF file...';
$status=NetCDF::close($nc_id);
die "Could not close netCDF file\n" if $status < 0;
print STDOUT "ok\n";
