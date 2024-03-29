#! /bin/bash
#
set -e
umask 002
pkg="rdbduprunner"
build_dir=$(mktemp -d)
url=https://github.com/aranc23/rdbduprunner
mkdir -p "${build_dir}"/{"usr/lib/${pkg}","usr/lib/${pkg}/check_mk/checks","usr/lib/${pkg}/check_mk/plugins","usr/lib/tmpfiles.d","etc/${pkg}/conf.d","run/${pkg}","var/log/${pkg}"} 

#cp $pkg ./Build/usr/bin/
cp check_mk/checks/rdbduprunner "${build_dir}/usr/lib/${pkg}/check_mk/checks/"
cp check_mk/plugins/rdbduprunner "${build_dir}/usr/lib/${pkg}/check_mk/plugins/"
cp "contrib/tmpfiles.d/${pkg}.conf" "${build_dir}/usr/lib/tmpfiles.d/"

tmp=$(mktemp)
grep -E 'our \$VERSION' lib/Backup/rdbduprunner.pm > $tmp
echo 'print $VERSION."\n"' >> $tmp

version=$(perl $tmp)
iteration=0
rm -f $tmp

#rpm_deps="-d perl-JSON -d perl-Log-Dispatch -d perl-Config-General -d perl-Readonly"
#deb_deps="--no-auto-depends -d libjson-perl -d liblog-dispatch-perl -d libconfig-general-perl -d libreadonly-perl -d libconfig-any-perl"
deb_deps="-d liburi-perl"
common_deps="-d perl -d rsync"
summary="script and module for making backups with rsync, rdiff-backup, and duplicity"
description="runs backup programs per a configuration file"
common_opts="--version ${version} --iteration ${iteration} -m arancox@gmail.com --architecture noarch -s cpan --prefix /usr --cpan-perl-lib-path /usr/share/perl5 --url ${url}"

cpan_reject=(Config vars warnings strict Encode Carp IO::Select IO::Handle Fcntl POSIX Sys::Hostname URI::Escape Scalar::Util File::Basename Data::Dumper Log::Dispatch::Screen Log::Dispatch::Syslog Log::Dispatch::File AnyDBM-File Sys::Hostname)
for mod in ${cpan_reject[@]}; do
    deb_deps="${deb_deps} --cpan-package-reject-from-depends ${mod}"
done

fpm -n $pkg --version ${version} --iteration ${iteration} -m arancox@gmail.com --architecture noarch -C $build_dir -s dir -d "perl-Backup-rdbduprunner = ${version}-${iteration}"    -t rpm --rpm-summary "${summary}" --description "${description}" --url "${url}" .
fpm -n $pkg --version ${version} --iteration ${iteration} -m arancox@gmail.com --architecture noarch -C $build_dir -s dir -d "libbackup-rdbduprunner-perl = ${version}-${iteration}" -t deb --rpm-summary "${summary}" --description "${description}" --url "${url}" .

rm -rf $build_dir

# create the packages for the Backup::rdbduprunner module
fpm --verbose --no-cpan-test $common_opts $common_deps $rpm_deps -t rpm --rpm-summary "${summary}" --description "${description}" .
fpm --verbose --no-cpan-test $common_opts $common_deps $deb_deps -t deb --rpm-summary "${summary}" --description "${description}" .

# build two packages missing on Ubuntu 20.04 needed by Backup::rdbduprunner:
for pkg in No::Worries Config::Validator; do
    fpm --verbose --no-cpan-test --prefix /usr --cpan-perl-lib-path /usr/share/perl5 -s cpan -t deb -m arancox@gmail.com $deb_deps $pkg || continue;
done

# build packages missing on CentOS7 needed by Backup::rdbduprunner:
fpm --verbose --no-cpan-test --prefix /usr --cpan-perl-lib-path /usr/share/perl5 -s cpan -t rpm -m arancox@gmail.com --name perl-Hash-Merge Hash::Merge  || echo "already exists"
fpm --verbose --no-cpan-test --prefix /usr --cpan-perl-lib-path /usr/share/perl5 -s cpan -t rpm -m arancox@gmail.com --name perl-Clone-Choose Clone::Choose || echo "already exists"
