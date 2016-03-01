Summary:        JSON-C library 
License:        MIT License        
Name:           json-c
Version:        %{json_ver}
Release:        %{json_rel}
Group:          Development/Tools
Prefix:         /temp
AutoReq:        no
AutoProv:       no
Provides:       json-c = %{json_ver} 

%description
The JSON-C module provides a JSON implementation in C which is used by PostGIS.

%install
mkdir -p %{buildroot}/temp/lib
cp -rf %{json_dir}/lib/libjson-c*so* %{buildroot}/temp/lib

%files
/temp
