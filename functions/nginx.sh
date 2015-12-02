#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# Blog:  http://blog.linuxeye.com

Install_Nginx()
{
cd $lnmp_dir/src
. ../functions/download.sh
. ../functions/check_os.sh
. ../options.conf

src_url=http://downloads.sourceforge.net/project/pcre/pcre/$pcre_version/pcre-$pcre_version.tar.gz && Download_src
src_url=http://nginx.org/download/nginx-$nginx_version.tar.gz && Download_src

tar xzf pcre-$pcre_version.tar.gz
cd pcre-$pcre_version
./configure
make && make install
cd ../

tar xzf nginx-$nginx_version.tar.gz
id -u $run_user >/dev/null 2>&1
[ $? -ne 0 ] && useradd -M -s /sbin/nologin $run_user
cd nginx-$nginx_version

# Modify Nginx version
#sed -i 's@#define NGINX_VERSION.*$@#define NGINX_VERSION      "1.2"@' src/core/nginx.h
#sed -i 's@#define NGINX_VER.*NGINX_VERSION$@#define NGINX_VER          "Linuxeye/" NGINX_VERSION@' src/core/nginx.h
#sed -i 's@Server: nginx@Server: linuxeye@' src/http/ngx_http_header_filter_module.c

# close debug
sed -i 's@CFLAGS="$CFLAGS -g"@#CFLAGS="$CFLAGS -g"@' auto/cc/gcc

if [ "$je_tc_malloc" == '1' ];then
	malloc_module="--with-ld-opt='-ljemalloc'"
elif [ "$je_tc_malloc" == '2' ];then
	malloc_module='--with-google_perftools_module'
	mkdir /tmp/tcmalloc
	chown -R ${run_user}.$run_user /tmp/tcmalloc
fi

[ ! -d "$nginx_install_dir" ] && mkdir -p $nginx_install_dir
./configure --prefix=$nginx_install_dir --user=$run_user --group=$run_user --with-http_stub_status_module --with-http_ssl_module --with-ipv6 --with-http_gzip_static_module --with-http_realip_module --with-http_flv_module $malloc_module
make && make install
if [ -d "$nginx_install_dir/conf" ];then
        echo -e "\033[32mNginx install successfully! \033[0m"
else
	rm -rf $nginx_install_dir
        echo -e "\033[31mNginx install failed, Please Contact the author! \033[0m"
        kill -9 $$
fi

[ -z "`grep ^'export PATH=' /etc/profile`" ] && echo "export PATH=$nginx_install_dir/sbin:\$PATH" >> /etc/profile
[ -n "`grep ^'export PATH=' /etc/profile`" -a -z "`grep $nginx_install_dir /etc/profile`" ] && sed -i "s@^export PATH=\(.*\)@export PATH=$nginx_install_dir/bin:\1@" /etc/profile
. /etc/profile

cd ../../
OS_CentOS='/bin/cp init/Nginx-init-CentOS /etc/init.d/nginx \n
chkconfig --add nginx \n
chkconfig nginx on'
OS_Debian_Ubuntu='/bin/cp init/Nginx-init-Ubuntu /etc/init.d/nginx \n
update-rc.d nginx defaults'
OS_command
sed -i "s@/usr/local/nginx@$nginx_install_dir@g" /etc/init.d/nginx

mv $nginx_install_dir/conf/nginx.conf{,_bk}
if [ "$Apache_version" == '1' -o "$Apache_version" == '2' ];then
	/bin/cp conf/nginx_apache.conf $nginx_install_dir/conf/nginx.conf
else
	/bin/cp conf/nginx.conf $nginx_install_dir/conf/nginx.conf
fi
sed -i "s@/home/wwwroot/default@$wwwroot_dir/default@" $nginx_install_dir/conf/nginx.conf
sed -i "s@/home/wwwlogs@$wwwlogs_dir@g" $nginx_install_dir/conf/nginx.conf
sed -i "s@^user www www@user $run_user $run_user@" $nginx_install_dir/conf/nginx.conf
[ "$je_tc_malloc" == '2' ] && sed -i 's@^pid\(.*\)@pid\1\ngoogle_perftools_profiles /tmp/tcmalloc;@' $nginx_install_dir/conf/nginx.conf

# worker_cpu_affinity
CPU_num=`cat /proc/cpuinfo | grep processor | wc -l`
if [ $CPU_num == 2 ];then
        sed -i 's@^worker_processes.*@worker_processes 2;\nworker_cpu_affinity 10 01;@' $nginx_install_dir/conf/nginx.conf
elif [ $CPU_num == 3 ];then
        sed -i 's@^worker_processes.*@worker_processes 3;\nworker_cpu_affinity 100 010 001;@' $nginx_install_dir/conf/nginx.conf
elif [ $CPU_num == 4 ];then
        sed -i 's@^worker_processes.*@worker_processes 4;\nworker_cpu_affinity 1000 0100 0010 0001;@' $nginx_install_dir/conf/nginx.conf
elif [ $CPU_num == 6 ];then
        sed -i 's@^worker_processes.*@worker_processes 6;\nworker_cpu_affinity 100000 010000 001000 000100 000010 000001;@' $nginx_install_dir/conf/nginx.conf
elif [ $CPU_num == 8 ];then
        sed -i 's@^worker_processes.*@worker_processes 8;\nworker_cpu_affinity 10000000 01000000 00100000 00010000 00001000 00000100 00000010 00000001;@' $nginx_install_dir/conf/nginx.conf
else
        echo Google worker_cpu_affinity
fi

# logrotate nginx log
cat > /etc/logrotate.d/nginx << EOF
$wwwlogs_dir/*nginx.log {
daily
rotate 5
missingok
dateext
compress
notifempty
sharedscripts
postrotate
    [ -e /var/run/nginx.pid ] && kill -USR1 \`cat /var/run/nginx.pid\`
endscript
}
EOF

sed -i "s@^web_install_dir.*@web_install_dir=$nginx_install_dir@" options.conf
ldconfig
service nginx start
}
