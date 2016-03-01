Summary:        Expat library
License:        MIT
Name:           libexpat
Version:        %{libexpat_ver}
Release:        %{libexpat_rel} 
Group:          Development/Tools
Prefix:         /temp
AutoReq:        no
AutoProv:       no
Provides:       libexpat = %{libexpat_ver}, /bin/sh

%description
Expat is an XML parser library written in C. It is a
stream-oriented parser in which an application registers handlers
for things the parser might find in the XML document (like start
tags). An introductory article on using Expat is available on
xml.com.

%install
mkdir -p %{buildroot}/temp/lib
cp -rf %{libexpat_dir}/lib/libexpat*so* %{buildroot}/temp/lib/

%files
/temp
