#
# spec file for package marmos
#
# Copyright (c) 2024 SUSE LLC
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via https://bugs.opensuse.org/
#


%define meson_buildtype release

Name:           marmos
Version:        0.0.0
Release:        0
Summary:        Documentation tooling for D
License:        MPL-2.0
Group:          Development/Tools/Doc Generators
URL:            https://github.com/Juptune/marmos
Source0:        marmos-%{version}.tar
BuildRequires:  ldc
BuildRequires:  ldc-phobos-devel
BuildRequires:  ldc-runtime-devel
BuildRequires:  meson

%description
Tool for genereating documentation-focused ASTs for the D programming
language, as part of a wider solution for generating a documentation site.

%prep
%setup -q

# For some reason, `osc build` is adding in a bad `--flto=auto` flag which LDC2 doesn't support.
# This doesn't happen with a raw `rpmbuild`. It's simple enough to fix though - we just won't use the meson setup macro.
%build
%{_bindir}/meson setup \
    --buildtype=%{meson_buildtype} \
    --prefix=%{_prefix} \
    --libdir=%{_libdir} \
    --libexecdir=%{_libexecdir} \
    --bindir=%{_bindir} \
    --sbindir=%{_sbindir} \
    --includedir=%{_includedir} \
    --datadir=%{_datadir} \
    --mandir=%{_mandir} \
    --infodir=%{_infodir} \
    --localedir=%{_localedir} \
    --sysconfdir=%{_sysconfdir} \
    --localstatedir=%{_localstatedir} \
    --sharedstatedir=%{_sharedstatedir} \
    --wrap-mode=nodownload \
    --auto-features=enabled \
    --strip \
    %{_vpath_srcdir} \
    %{_vpath_builddir}
%meson_build

%install
%meson_install

%if "%{meson_buildtype}" == "debug" || "%{meson_buildtype}" == "debugoptimized"
%check
%meson_test
%endif

%files
%license LICENSE.txt
%doc README.md
%{_bindir}/marmos

%changelog
