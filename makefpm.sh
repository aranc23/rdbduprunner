#! /bin/bash
#
pkg=rdbduprunner
#rm -rf ./Build/*
#mkdir -p ./Build/{usr/bin,"usr/lib/${pkg}","usr/lib/tmpfiles.d","etc/${pkg}/conf.d","run/${pkg}","var/log/${pkg}"} 

#cp $pkg ./Build/usr/bin/
#rsync -av check_mk "./Build/usr/lib/${pkg}"
#cp "contrib/tmpfiles.d/${pkg}.conf" ./Build/usr/lib/tmpfiles.d/

version=$(git tag -l | tail -1 | sed 's/^v//' )
summary="script for making backups with rsync, rdiff-backup, and duplicity"
description="runs backup programs per a configuration file"
#rpm_deps="-d perl-JSON -d perl-Log-Dispatch -d perl-Config-General -d perl-Readonly"
#deb_deps="-d libjson-perl -d liblog-dispatch-perl -d libconfig-general-perl -d libreadonly-perl"
common_deps="-d perl -d rsync"
common_opts="--version ${version} --architecture noarch -s cpan --prefix /usr --replaces rdbduprunner --cpan-perl-lib-path /usr/share/perl5 ."

fpm $common_opts $common_deps $rpm_deps -t rpm --rpm-summary "${summary}" --description "${description}" .
fpm $common_opts $common_deps $deb_deps -t deb --rpm-summary "${summary}" --description "${description}" .

