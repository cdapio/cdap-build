set -e

DIST_DIR_INSTALLER="ansible_rpm/"

rm -rf ansible_rpm/*
VERSION="5.1"
DATE=`date +'%Y%m%d'`

echo -e "# # # # # # # START : Creating RPM package Solution Installer # # # # # # #"
fpm -f -s dir -t rpm --rpm-os linux -v ${VERSION} --iteration ${DATE} --chdir ansible -p $DIST_DIR_INSTALLER -n ansible_rpm .
echo -e "# # # # # # # # END : Creating RPM package for Solution Installer # # # # # # #"

popd > /dev/null
