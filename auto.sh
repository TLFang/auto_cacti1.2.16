#!/bin/bash
#
# OS:CENTOS 7 X86_64
#
version=1.2.16
std_dir=$(pwd)
function Idendify()
{
	
	if [ $UID -ne 0 ];then
		echo "Must run as root!"
		cd
		rm -rf $std_dir
		exit 1
	fi
}
#禁用selinux
function Disable_selinux()
{
	setenforce 0
#
	sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
#
}
#建立mariadb10源
function Rebuild_repo()
{
	echo -e "[mariadb]\nname = MariaDB\nbaseurl = https://mirrors.ustc.edu.cn/mariadb/yum/10.3/centos7-amd64\ngpgkey = https://mirrors.ustc.edu.cn/mariadb/yum/RPM-GPG-KEY-MariaDB\ngpgcheck = 1" >/etc/yum.repos.d/CentOS-MariaDB.repo
#重建软件源缓存
	yum clean all
	yum makecache
}
#安装依赖
function Install_base_env()
{
	yum -y install gcc make automake httpd php php-mysql php-snmp php-xml php-gd php-ldap php-mbstring php-posix MariaDB-client MariaDB-server MariaDB-devel MariaDB-compat MariaDB-common pcre-devel pango pango-devel  cairo-devel libxml2-devel pixman-devel perl-devel fontconfig-devel freetype libpng-devel binutils cpp net-snmp net-snmp-utils net-snmp-devel  openssl-devel autoconf binutils dos2unix libtool glibc-devel glibc-headers kernel-headers wget patch fontconfig ttmkfdir
}
#
#安装rrdtool
function Install_rrdtool()
{
	tar -xzvf rrdtool-1.7.2.tar.gz
	cd rrdtool-1.7.2/
	sed -i 's/RRDTOOL \/ TOBI OETIKER/YUNWEI PASSWD \/ Based on cacti/' src/rrd_graph.c
	./configure
	make && make install
	cd ../
	cp /opt/rrdtool-1.7.2/bin/* /usr/bin/
}
#
#启动SNMP
function Start_snmp()
{
	systemctl enable snmpd
	systemctl start snmpd
}
#安装cacti-spine
function Install_spine()
{
	tar zxvf cacti-spine-$version.tar.gz
	cd cacti-spine-$version/
	./bootstrap
	./configure
	make
	cp spine /usr/bin/spine
	cp spine.conf.dist /etc/spine.conf
	cd ../
	chown apache.apache /etc/spine.conf
	sed -i '/^DB_Pass/c\DB_Pass    am9pbmRhdGEubmV0Cg\' /etc/spine.conf
}
#
#启动数据库
#
function Start_mariadb()
{
	systemctl enable mariadb
	systemctl start mariadb
}
#
function Create_db()
{
	mysqladmin -uroot password 'am9pbmRhdGEubmV0Cg'
#
	mysql -uroot -pam9pbmRhdGEubmV0Cg -e "create database cacti;"
#
	mysql -uroot -pam9pbmRhdGEubmV0Cg -e "grant all on cacti.* to cactiuser@'localhost' identified by 'am9pbmRhdGEubmV0Cg';"
#
	mysql -uroot -pam9pbmRhdGEubmV0Cg -e "flush privileges;"
#
	mysql -uroot -pam9pbmRhdGEubmV0Cg -e "ALTER DATABASE cacti CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
}
#
#安装cacti
function Install_cacti()
{
	tar zxvf cacti-$version.tar.gz
	mv cacti-$version /var/www/html/cacti
#
	chmod -R a-w /var/www/html/cacti/
	chown -R apache /var/www/html/cacti/resource/snmp_queries/
	chown -R apache /var/www/html/cacti/resource/script_server/
	chown -R apache /var/www/html/cacti/resource/script_queries/
	chown -R apache /var/www/html/cacti/scripts/
	chown -R apache /var/www/html/cacti/cache/boost/
	chown -R apache /var/www/html/cacti/cache/mibcache/
	chown -R apache /var/www/html/cacti/cache/realtime/
	chown -R apache /var/www/html/cacti/cache/spikekill/
#
	chmod -R u+w /var/www/html/cacti/resource/snmp_queries/
	chmod -R u+w /var/www/html/cacti/resource/script_server/
	chmod -R u+w /var/www/html/cacti/resource/script_queries/
	chmod -R u+w /var/www/html/cacti/scripts/
	chmod -R u+w /var/www/html/cacti/cache/boost/
	chmod -R u+w /var/www/html/cacti/cache/mibcache/
	chmod -R u+w /var/www/html/cacti/cache/realtime/
	chmod -R u+w /var/www/html/cacti/cache/spikekill/

#
#导入数据库
#
	mysql -u cactiuser -pam9pbmRhdGEubmV0Cg cacti</var/www/html/cacti/cacti.sql
#
	chmod -R 777 /var/www/html/cacti/rra
	chmod -R 777 /var/www/html/cacti/log
	chown -R apache.apache /var/www/html/cacti/rra
	chown -R apache.apache /var/www/html/cacti/log
#
}
#测试一下spine
#
function Test_spine()
{
	/usr/bin/spine
#
}
#修改cacti全局配置文件
#
function Config_cacti()
{
	sed -i '/^\$database_default/c\\$database_default = '\''cacti'\'';' /var/www/html/cacti/include/config.php
#
	sed -i '/^\$database_username/c\\$database_username = '\''cactiuser'\'';' /var/www/html/cacti/include/config.php
#
	sed -i '/^\$database_password/c\\$database_password = '\''am9pbmRhdGEubmV0Cg'\'';' /var/www/html/cacti/include/config.php
#
#修改时区
	sed -i '24a\date_default_timezone_set('\''Asia/Shanghai'\'');' /var/www/html/cacti/include/global.php
#
}
#添加计划任务
#
function Add_cron()
{
	echo "*/5 * * * * /usr/bin/php /var/www/html/cacti/poller.php >> /tmp/cacti_rrdtool.log 2>&1" |crontab
#
}
#修改php.ini
#
function Config_php()
{
	sed -i '/memory_limit/c\memory_limit = 1536M\' /etc/php.ini
#
	sed -i '/max_execution_time/c\max_execution_time = 100' /etc/php.ini
#
	sed -i '/date.timezone =/c\date.timezone = "Asia/Shanghai"\' /etc/php.ini
}
#
#配置数据库特性
#
function config_mariadb()
{
	sed -i '/\[mysqld\]/a\character_set_server=utf8mb4' /etc/my.cnf.d/server.cnf
	sed -i '/\[mysqld\]/a\character_set_client=utf8mb4'  /etc/my.cnf.d/server.cnf
	sed -i '/\[mysqld\]/a\collation_server=utf8mb4_unicode_ci'  /etc/my.cnf.d/server.cnf
	sed -i '/\[mysqld\]/a\max_heap_table_size=768M'  /etc/my.cnf.d/server.cnf
	sed -i '/\[mysqld\]/a\tmp_table_size=768M'  /etc/my.cnf.d/server.cnf
	sed -i '/\[mysqld\]/a\join_buffer_size=1024M'  /etc/my.cnf.d/server.cnf
	sed -i '/\[mysqld\]/a\innodb_file_format=Barracuda'  /etc/my.cnf.d/server.cnf
	sed -i '/\[mysqld\]/a\innodb_large_prefix=1'  /etc/my.cnf.d/server.cnf
	sed -i '/\[mysqld\]/a\innodb_buffer_pool_size=8192M'  /etc/my.cnf.d/server.cnf
	sed -i '/\[mysqld\]/a\innodb_flush_log_at_timeout=3'  /etc/my.cnf.d/server.cnf
	sed -i '/\[mysqld\]/a\innodb_read_io_threads=32'  /etc/my.cnf.d/server.cnf
	sed -i '/\[mysqld\]/a\innodb_write_io_threads=16'  /etc/my.cnf.d/server.cnf
	sed -i '/\[mysqld\]/a\innodb_buffer_pool_instances=64'  /etc/my.cnf.d/server.cnf
	sed -i '/\[mysqld\]/a\innodb_io_capacity=400'  /etc/my.cnf.d/server.cnf
	sed -i '/\[mysqld\]/a\innodb_io_capacity_max=4000'  /etc/my.cnf.d/server.cnf
#

#导入mysql时区
#

	cd /bin
	mysql_tzinfo_to_sql /usr/share/zoneinfo |mysql -uroot -pam9pbmRhdGEubmV0Cg mysql
#
	mysql -uroot -pam9pbmRhdGEubmV0Cg -e "grant select on mysql.time_zone_name to cactiuser@'localhost';"
#
	systemctl restart mariadb
}
#上传字体
#
function config_font()
{
	cd /usr/share/fonts/
	mkdir chinese
#
	cp $std_dir/FZHTK.TTF chinese/
#
	ttmkfdir -e /usr/share/X11/fonts/encodings/encodings.dir
#
	fc-cache
#
}
function Install_plugins()
{
	cd $std_dir
	tar xzvf plugin_monitor-2.3.6.tar.gz
	tar xzvf plugin_thold-1.3.2.tar.gz
	mv plugin_monitor-2.3.6 /var/www/html/cacti/plugins/monitor
	mv plugin_thold-develop /var/www/html/cacti/plugins/thold
}
#启动httpd
#
function Start_httpd()
{
	systemctl enable httpd
	systemctl start httpd
#
}
#
function Config_firewall()
{
	firewall-cmd --permanent --add-service http
	firewall-cmd --add-service http
}
#
Idendify
#
Disable_selinux
#
Rebuild_repo
#
Install_base_env
#
Install_rrdtool
#
Start_snmp
#
Install_spine
#
Start_mariadb
#
Create_db
#
Install_cacti
#
Test_spine
#
Config_cacti
#
Add_cron
#
Config_php
#
config_mariadb
#
config_font
#
Install_plugins
#
Start_httpd
#
Config_firewall
#
exit 0
#
