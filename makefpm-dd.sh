#! /bin/bash
#
set -e
umask 002
pkg=delta-dumper
build_dir=$(mktemp -d)
mkdir -p $build_dir/{usr/bin,usr/lib/{$pkg,tmpfiles.d},etc/$pkg,run/$pkg} 
mkdir -p "${build_dir}"/{"usr/lib/${pkg}","usr/lib/${pkg}/check_mk/checks","usr/lib/${pkg}/check_mk/plugins","usr/lib/tmpfiles.d","run/${pkg}","var/log/${pkg}"} 

cp delta-dumper "${build_dir}/usr/bin/"
cp config.sample "${build_dir}/etc/delta-dumper/"
cp check_mk/checks/delta_dumper "${build_dir}/usr/lib/${pkg}/check_mk/checks/"
cp check_mk/plugins/delta_dumper "${build_dir}/usr/lib/${pkg}/check_mk/plugins/"
cp contrib/tmpfiles.d/delta-dumper.conf "${build_dir}/usr/lib/tmpfiles.d/"

tmp=$(mktemp)
grep -E 'our \$VERSION' lib/Backup/rdbduprunner.pm > $tmp
echo 'print $VERSION."\n"' >> $tmp

version=$(perl $tmp)
iteration=0
rm -f $tmp

summary="script for managing compact mysql, postgres, and mongodb dumps"
description="dumps databases and optionally compresses or diffs them using xdelta3"
rpm_deps="-d perl-JSON -d perl-Log-Dispatch -d perl-AppConfig -d xdelta -d xz -d perl-Readonly"
deb_deps="-d libjson-perl -d liblog-dispatch-perl -d libappconfig-perl -d xdelta3 -d xz-utils -d libreadonly-perl"
common_deps="-d perl -d mbuffer -d gzip -d bzip2 -d zstd -d rsync"
common_opts="-n ${pkg} --version $version --architecture noarch -C ${build_dir} -s dir"
url="https://github.com/aranc23/rdbduprunner"

fpm  -d "perl-Backup-delta-dumper = ${version}-${iteration}" $common_opts $common_deps $rpm_deps -t rpm --rpm-summary "${summary}" --description "${description}" --url "${url}" .
fpm  -d "libbackup-rdbduprunner-perl = ${version}-${iteration}" $common_opts $common_deps $deb_deps -t deb --rpm-summary "${summary}" --description "${description}" --url "${url}" .

rm -rf $build_dir
