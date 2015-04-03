NetCDF Perl
===================
Greetings!  This file briefly describes the Unidata netCDF Perl package.

----------


###Table of Contents
* [Notice of Deprecation](#Notice_of_Deprecation)
* [Introduction](#Introduction)
* [Availability](#Availability)
* [Installation](#Installation)
* [Support & Mailing List](#Support)
* [Known Problems](#Known_Problems)
* [Additional Information](Additional_Information)

----------
### <a name="Notice_of_Deprecation"></a>Notice of Deprecation
> **Note**: The netCDF Perl package is **no longer being actively maintained** by the Unidata program center. Unidata will continue to provide support for Unidata netCDF Perl.

### <a name="Introduction"></a>Introduction
The netCDF Perl package is a perl extension module for scientific data access via the netCDF API.

The netCDF Perl package is a perl extension for accessing netCDF  datasets based on version 2 of the netCDF package (netCDF-2).  For example, the following netCDF-2 actions:

1.  Open dataset "foo.nc";

2.  Write a 2 x 3 array of double-precision values into the  starting corner of the first variable; and

3.  Close the dataset.

can be accomplished by the following C fragment:

```
        int     ncid = ncopen("foo.nc", NC_WRITE);
        int     varid = 0;
        long    start[2], count[2];
        double  values[6];

        ncid = ncopen("foo.nc", NC_WRITE);

        start[0] = 0;
        start[1] = 0;
        count[0] = 2;
        count[1] = 3;

        values[0] = 0.0;
        values[1] = 1.0;
        values[2] = 2.0;
        values[3] = 3.0;
        values[4] = 4.0;
        values[5] = 5.0;

        ncvarput(ncid, varid, start, count, values);

        ncclose(ncid);
```
or by this equivalent perl fragment:
```
        use NetCDF;

        $ncid = NetCDF::open("foo.nc", NetCDF::WRITE);
        $varid = 0;
        @start = (0, 0);
        @count = (2, 3);
        @values = (0, 1, 2, 3, 4, 5);
        NetCDF::varput($ncid, $varid, \@start, \@count, \@values);
        NetCDF::close($ncid);
```
There are perl-callable functions for all appropriate functions of the netCDF-2 API.

> netCDF-2 vs. netCDF-3

> Currently, the netCDF Perl extension module is implemented using version 2 of the netCDF API (netCDF-2).  On 1997-05-16, version 3 of the netCDF package was released (netCDF-3).  This newer version, however, contains a netCDF-2 backward compatibility interface. Thus, with a few minor changes already made, netCDF Perl works with   netCDF-3 as well as netCDF-2.

>Users should be aware, however, that the netCDF Perl user-interface is based on netCDF-2.  In particular, the netCDF Perl documentation doesn't describe the netCDF Perl interface in detail but instead describes the differences between it and the netCDF-2 interface. The intention was that users would use the netCDF Perl and netCDF-2 documentation together in order to program using netCDF Perl.

> With the deprecation of the netCDF-2 interface, this has become slightly problematical -- but not unworkable.  The solution is to ensure the availability of the netCDF-2 documentation.  

> The [Unidata netCDF library web site](http://www.unidata.ucar.edu/software/netcdf) contains user guides, manual pages, information on the various versions of netCDF, and more.

	
### <a name="Availability"></a>Availability

**Unidata netCDF Perl**
...Other than the source here on GitHub, Unidata netCDF Perl is freely available for download at: ftp://ftp.unidata.ucar.edu/pub/netcdf-perl/

**Other Sources**

> Note:  The following are third-party and have not been verified or validated by the Unidata Program Center. 

...[RedHat RPM & ncmanipulate](http://home.badc.rl.ac.uk/iwi/netcdf-perl/) Alan Iwi's source and binary RPMs for RedHat Linux and ncmanipulate module to manipulate NetCDF files.
...[Fedora Installation](https://apps.fedoraproject.org/packages/netcdf-perl) Fedora provides a package called "netcdf-perl".
...[PDL::NetCDF](http://search.cpan.org/~dhunt/PDL-NetCDF-4.05/netcdf.pd) Doug Hunt's perl interface which uses the PDL (perl data language) extension.


### <a name="Installation"></a>Installation
See the file [INSTALL](INSTALL) in the top-level directory of the netCDF Perl distribution for instructions on how to incorporate netCDF Perl into your perl utility.

> Note: You will need write access to your installed perl(1) libraries in order to install netCDF Perl.

The netCDF Perl [manual page](man/man1/netCDFPerl.1) details how to use the NetCDF Perl package.

Read the list of [known problems](#Known_Problems) with the netCDF Perl package.

### <a name="Support"></a>Support & Mailing List

**Requesting Support**
...support from Unidata netCDF Perl developers:  <support-netcdf-perl@unidata.ucar.edu> 
...also view current and past [netCDF perl support questions]( http://www.unidata.ucar.edu/support/help/MailArchives/netcdf-perl/maillist.html) answered by Unidata developers.

**Defunct Mailing List**
...Perl had a community mailing list associated with it at one time. The mailing list is **no longer active**, but the [list archive](http://www.unidata.ucar.edu/mailing_lists/archives/netcdf-perl/) is still available for reference.

### <a name="Known_Problems"></a>Known Problems

**netCDFPerl doesn't install under OSF/1**
...make install might fail to install the netCDFPerl package under OSF/1. This might be due to a bug in make(1). The solution is to move the line
````
.PRECIOUS: Makefile
````
in the file perl/Makefile to after the all target.

### <a name="Additional_Information"></a>Additional Information

* [Unidata netCDF library](http://www.unidata.ucar.edu/software/netcdf/)
