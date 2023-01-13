Summary:        CGAL library 
License:        LGPL        
Name:           cgal
Version:        %{cgal_ver}
Release:        %{cgal_rel}
Group:          Development/Tools
Prefix:         /temp
AutoReq:        no
AutoProv:       no
Provides:       cgal = %{cgal_ver} 

%define _build_id_links none

%description
SFCGAL is a C++ wrapper library around CGAL with the aim of supporting ISO 19107:2013 and OGC Simple Features Access 1.2 for 3D operations.

%install
mkdir -p %{buildroot}/temp/lib
cp -rf %{cgal_dir}/lib64/* %{buildroot}/temp/lib

%files
/temp
