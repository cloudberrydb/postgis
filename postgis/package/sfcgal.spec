Summary:        SFCGAL library 
License:        LGPL        
Name:           sfcgal
Version:        %{sfcgal_ver}
Release:        %{sfcgal_rel}
Group:          Development/Tools
Prefix:         /temp
AutoReq:        no
AutoProv:       no
Provides:       sfcgal-c = %{sfcgal_ver} 

%define _build_id_links none

%description
SFCGAL is a C++ wrapper library around CGAL with the aim of supporting ISO 19107:2013 and OGC Simple Features Access 1.2 for 3D operations.

%install
mkdir -p %{buildroot}/temp/lib
cp -rf %{sfcgal_dir}/lib64/libSFCGA*so* %{buildroot}/temp/lib

%files
/temp
