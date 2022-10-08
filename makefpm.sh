#! /bin/bash
#
pkg=rdbduprunner
rm -rf ./Build/*
mkdir -p ./Build/{usr/bin,"usr/lib/$pkg}","etc/${pkg}/conf.d","var/run/${pkg}","var/log/${pkg}"} 

cp rdbduprunner ./Build/usr/bin/
rsync -av check_mk "./Build/usr/lib/${pgk}"

version=$(git tag -l | tail -1 | sed 's/^v//' )
summary="script for making backups with rsync, rdiff-backup, and duplicity"
description="runs backup programs per a configuration file"
rpm_deps="-d perl-JSON -d perl-Log-Dispatch -d perl-Config-General"
deb_deps="-d libjson-perl -d liblog-dispatch-perl -d libconfig-general-perl"
common_deps="-d perl -d rsync"
common_opts="-n rdbduprunner --version "${version}" --architecture noarch -C ./Build -s dir"

fpm $common_opts $common_deps $rpm_deps -t rpm --rpm-summary "${summary}" --description "${description}" .
fpm $common_opts $common_deps $deb_deps -t deb --rpm-summary "${summary}" --description "${description}" .

