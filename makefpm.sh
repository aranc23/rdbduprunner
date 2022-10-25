#! /bin/bash
#
set -e
umask 002
pkg="rdbduprunner"

rm -rf ./Build/*
mkdir -p ./Build/{"usr/lib/${pkg}","usr/lib/tmpfiles.d","etc/${pkg}/conf.d","run/${pkg}","var/log/${pkg}"} 

#cp $pkg ./Build/usr/bin/
rsync -av check_mk "./Build/usr/lib/${pkg}"
cp "contrib/tmpfiles.d/${pkg}.conf" ./Build/usr/lib/tmpfiles.d/

tmp=$(mktemp)
egrep 'our \$VERSION' lib/Backup/rdbduprunner.pm > $tmp
echo 'print $VERSION."\n"' >> $tmp

version=$(perl $tmp)
iteration=3
rm -f $tmp

#rpm_deps="-d perl-JSON -d perl-Log-Dispatch -d perl-Config-General -d perl-Readonly"
#deb_deps="--no-auto-depends -d libjson-perl -d liblog-dispatch-perl -d libconfig-general-perl -d libreadonly-perl -d libconfig-any-perl"
deb_deps="-d liburi-perl"
common_deps="-d perl -d rsync"
common_opts="--version ${version} --iteration ${iteration} -m arancox@gmail.com --architecture noarch -s cpan --prefix /usr --replaces perl-backup-rdbduprunner --cpan-perl-lib-path /usr/share/perl5"

cpan_reject=(Config vars warnings strict Encode Carp IO::Select IO::Handle Fcntl POSIX Sys::Hostname URI::Escape Scalar::Util AnyDBM_File File::Basename Data::Dumper Log::Dispatch::Screen Log::Dispatch::Syslog Log::Dispatch::File AnyDBM-File)
for mod in ${cpan_reject[@]}; do
    deb_deps="${deb_deps} --cpan-package-depend-reject ${mod}"
done

summary="script for making backups with rsync, rdiff-backup, and duplicity"
description="runs backup programs per a configuration file"

fpm -n $pkg --version ${version} --iteration ${iteration} -m arancox@gmail.com --architecture noarch -C ./Build -s dir -d perl-Backup-rdbduprunner    -t rpm --rpm-summary "${summary}" --description "${description}" .
fpm -n $pkg --version ${version} --iteration ${iteration} -m arancox@gmail.com --architecture noarch -C ./Build -s dir -d libbackup-rdbduprunner-perl -t deb --rpm-summary "${summary}" --description "${description}" .

summary="module for making backups with rsync, rdiff-backup, and duplicity"
#description="runs backup programs per a configuration file"

fpm --verbose $common_opts $common_deps $rpm_deps -t rpm --rpm-summary "${summary}" --description "${description}" --name perl-Backup-rdbduprunner .
fpm --verbose $common_opts $common_deps $deb_deps -t deb --cpan-package-name-prefix lib --rpm-summary "${summary}" --description "${description}" .

for pkg in No::Worries Config::Validator; do
    fpm --verbose --iteration $iteration --prefix /usr --cpan-perl-lib-path /usr/share/perl5 -s cpan -t deb -m arancox@gmail.com $deb_deps $pkg
done
