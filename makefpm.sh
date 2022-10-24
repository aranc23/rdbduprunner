#! /bin/bash
#
set -e
#pkg=rdbduprunner
#rm -rf ./Build/*
#mkdir -p ./Build/{usr/bin,"usr/lib/${pkg}","usr/lib/tmpfiles.d","etc/${pkg}/conf.d","run/${pkg}","var/log/${pkg}"} 

#cp $pkg ./Build/usr/bin/
#rsync -av check_mk "./Build/usr/lib/${pkg}"
#cp "contrib/tmpfiles.d/${pkg}.conf" ./Build/usr/lib/tmpfiles.d/

tmp=$(mktemp)
egrep 'our \$VERSION' lib/Backup/rdbduprunner.pm > $tmp
echo 'print $VERSION."\n"' >> $tmp

version=$(perl $tmp)
rm -f $tmp

summary="script for making backups with rsync, rdiff-backup, and duplicity"
description="runs backup programs per a configuration file"
#rpm_deps="-d perl-JSON -d perl-Log-Dispatch -d perl-Config-General -d perl-Readonly"
deb_deps="--no-auto-depends -d libjson-perl -d liblog-dispatch-perl -d libconfig-general-perl -d libreadonly-perl -d libconfig-any-perl"
common_deps="-d perl -d rsync"
common_opts="--version ${version} --architecture noarch -s cpan --prefix /usr --replaces rdbduprunner --replaces perl-backup-rdbduprunner --cpan-perl-lib-path /usr/share/perl5"

fpm --verbose $common_opts $common_deps $rpm_deps -t rpm --rpm-summary "${summary}" --description "${description}" .
fpm --verbose $common_opts $deb_deps -t deb --cpan-package-name-prefix lib --name libbackup-rdbduprunner-perl --rpm-summary "${summary}" --description "${description}" .


 #Depends: perl(AnyDBM-File), lib-config-any, lib-config-general, lib-config-validator, lib-data-dumper, lib-file-basename, lib-file-path, lib-file-spec, lib-json, lib-log-dispatch, lib-log-dispatch-file, lib-log-dispatch-screen, lib-log-dispatch-syslog, lib-readonly, lib-storable, libjson-perl, liblog-dispatch-perl, libconfig-general-perl, libreadonly-perl, libconfig-any-perl

