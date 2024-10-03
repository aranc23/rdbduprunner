#! /bin/bash
#
set -e
umask 002
pkg=delta-dumper
build_dir=$(mktemp -d)
mkdir -p $build_dir/{usr/bin,usr/lib/{$pkg,tmpfiles.d},etc/$pkg,run/$pkg} 
mkdir -p "${build_dir}"/{"usr/lib/${pkg}","usr/lib/${pkg}/check_mk/checks","usr/lib/${pkg}/check_mk/plugins","usr/lib/tmpfiles.d","run/${pkg}","var/log/${pkg}"} 

install delta-dumper "${build_dir}/usr/bin/"
install -m 0644 config.sample "${build_dir}/etc/delta-dumper/"
install check_mk/checks/delta_dumper "${build_dir}/usr/lib/${pkg}/check_mk/checks/"
install check_mk/plugins/delta_dumper "${build_dir}/usr/lib/${pkg}/check_mk/plugins/"
install -m 0644 contrib/tmpfiles.d/delta-dumper.conf "${build_dir}/usr/lib/tmpfiles.d/"
#ls -lR $build_dir

tmp=$(mktemp)
grep -E 'our \$VERSION' lib/Backup/rdbduprunner.pm > $tmp
echo 'print $VERSION."\n"' >> $tmp

version=$(perl $tmp)
iteration=0
rm -f $tmp

summary="script for managing compact mysql, postgres, and mongodb dumps"
description="dumps databases and optionally compresses or diffs them using xdelta3"
rpm_deps="-d perl-JSON -d perl-AppConfig -d xdelta -d xz"
deb_deps="-d libjson-perl -d libappconfig-perl -d xdelta3 -d xz-utils"
common_deps="-d perl -d mbuffer -d gzip -d bzip2 -d zstd -d rsync"
common_opts="-n ${pkg} --version $version --architecture noarch -C ${build_dir} -s dir"
url="https://github.com/aranc23/rdbduprunner"

fpm  -d "perl-Backup-rdbduprunner = ${version}-${iteration}" $common_opts $common_deps $rpm_deps -t rpm --rpm-summary "${summary}" --description "${description}" --url "${url}" .
fpm  -d "libbackup-rdbduprunner-perl = ${version}-${iteration}" $common_opts $common_deps $deb_deps -t deb --rpm-summary "${summary}" --description "${description}" --url "${url}" .

rm -rf $build_dir
