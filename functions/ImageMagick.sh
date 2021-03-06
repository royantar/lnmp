#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# Blog:  http://blog.linuxeye.com

Install_ImageMagick()
{
cd $lnmp_dir/src
. ../functions/download.sh
. ../options.conf

src_url=http://downloads.sourceforge.net/project/imagemagick/old-sources/6.x/6.8/ImageMagick-$ImageMagick_version.tar.gz && Download_src

tar xzf ImageMagick-$ImageMagick_version.tar.gz
cd ImageMagick-$ImageMagick_version
./configure --prefix=/usr/local/imagemagick
make && make install
cd ../
/bin/rm -rf ImageMagick-$ImageMagick_version

if [ -e "$php_install_dir/bin/phpize" ];then
	src_url=http://pecl.php.net/get/imagick-$imagick_version.tgz && Download_src
	tar xzf imagick-$imagick_version.tgz
	cd imagick-$imagick_version
	make clean
	export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
	$php_install_dir/bin/phpize
	./configure --with-php-config=$php_install_dir/bin/php-config --with-imagick=/usr/local/imagemagick
	make && make install
	cd ../
	/bin/rm -rf imagick-$imagick_version

	if [ -f "$php_install_dir/lib/php/extensions/`ls $php_install_dir/lib/php/extensions | grep zts`/imagick.so" ];then
		[ -z "`cat $php_install_dir/etc/php.ini | grep '^extension_dir'`" ] && sed -i "s@extension_dir = \"ext\"@extension_dir = \"ext\"\nextension_dir = \"$php_install_dir/lib/php/extensions/`ls $php_install_dir/lib/php/extensions | grep zts`\"@" $php_install_dir/etc/php.ini
		sed -i 's@^extension_dir\(.*\)@extension_dir\1\nextension = "imagick.so"@' $php_install_dir/etc/php.ini
	        [ "$Apache_version" != '1' -a "$Apache_version" != '2' ] && service php-fpm restart || service httpd restart
	else
	        echo -e "\033[31mPHP imagick module install failed, Please contact the author! \033[0m"
	fi
fi
cd ../
}
