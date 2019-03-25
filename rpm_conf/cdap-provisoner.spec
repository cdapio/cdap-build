Name:        cdap-provisioner
Version:     @@RPM_VERSION@@
Release:     @@RPM_RELEASE@@.69%{?dist}
Summary:     The Reflex Third Party Software Manager.
Vendor:      Guavus Network Systems
License:     Proprietary 
URL:         http://www.guavus.com
BuildRoot:   %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
Packager:    Reflex Solution 
Source0:     cdap-provisioner-%{version}.tar

### Dependencies ###

%define debug_package %{nil}

%define _unpackaged_files_terminate_build 0

%global __os_install_post %{nil}

%global reflex_root_prefix /etc/reflex-provisioner/
%global raf_repo_path /opt/repos/raf/

%description
The Raf Provisioner Third Party Software Manager.

%prep
%setup -q

%build
# We don't build. We just install.

%install

# We cannot do this in the RPM creating script because of assumptions of
# rpmbuild wrt to the Source section.
#
mkdir -p ${RPM_BUILD_ROOT}/%{reflex_root_prefix}/
mkdir -p ${RPM_BUILD_ROOT}/%{reflex_root_prefix}/playbooks/
mkdir -p ${RPM_BUILD_ROOT}/%{reflex_root_prefix}/roles/
mkdir -p ${RPM_BUILD_ROOT}/%{reflex_root_prefix}/inventory/templates/group_vars/global/all/raf/
mkdir -p ${RPM_BUILD_ROOT}/%{raf_repo_path}/rpms
mkdir -p ${RPM_BUILD_ROOT}/%{raf_repo_path}/docker
cp -rfP ./ansible/playbooks/raf ${RPM_BUILD_ROOT}/%{reflex_root_prefix}/playbooks/
cp -rfP ./ansible/roles/raf ${RPM_BUILD_ROOT}/%{reflex_root_prefix}/roles/
cp -rfP ./ansible/inventory/group_vars/all.yml ${RPM_BUILD_ROOT}/%{reflex_root_prefix}/inventory/templates/group_vars/global/all/raf/cdap.yml
cp -rfP ./ansible/inventory/group_vars/cdap-security.yml ${RPM_BUILD_ROOT}/%{reflex_root_prefix}/inventory/templates/group_vars/global/all/raf/cdap-security.yml
cp -rfP ./ansible/inventory/group_vars/cdap-security-precheck.yml ${RPM_BUILD_ROOT}/%{reflex_root_prefix}/inventory/templates/group_vars/global/all/raf/cdap-security-precheck.yml

# Copying cdap_security.tar 
cp -rfP ./cdap_security.tar ${RPM_BUILD_ROOT}/%{raf_repo_path}/

# Copying cdap_security.tar 
cp -rfP ./cdap_security.tar ${RPM_BUILD_ROOT}/%{raf_repo_path}/


%clean
rm -rf %{buildroot}

%pre

%post
ldconfig

%preun

%postun

%files

%attr(-, root, root) /etc/
%attr(-, root, root) /opt/

%changelog
