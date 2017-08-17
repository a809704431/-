#/bin/bash
set -e
set -u

#确认hostname合法性
CheckHost=`echo $(hostname)|cut -c1-2`
if [ $CheckHost != "DB" ];then
	echo "请先设定好主机名,规范:DBxx_xx"
	exit
else
	echo "hostname符合规范.程序继续执行..."
fi


TEMP=`getopt -o hs:x:d:c: -a -l help,slave:,ratio:,ssd:,charset -n "Type '-h' for help..." -- "$@"`  
# 判定 getopt 的执行时候有错，错误信息输出到 STDERR  
if [ $? != 0 ]  
then  
    echo "Terminating....."  >&2
    exit 1  
fi  
# 使用eval 的目的是为了防止参数中有shell命令，被错误的扩展。  
eval set -- "$TEMP"  

usage()
{
	 echo "

==========================================================================================
Info  :
        Created By laowantong@baofu.com
Usage :
Command line options :

   -h,--help           Print Help Info. 
   -s,--slave          Slave or Master. 
   -x,--ratio          ratio of R/W. Format:(n:m) 
   -d,--ssd            SSD or Not
   -c,--charset        utf8 or utf8mb4

Sample :
   shell> MysqlInstall.sh -s y -x 2:1 -d y  -c utf8mb4
==========================================================================================
"
#exit
}

# 处理具体的选项  
while true  
do  
    case "$1" in  
        -s | --slave | -slave)  
            CHK_SLAVE=$2
            shift 2
            ;;  
        -x | --ratio | -ratio)  
            rw_ratio=$2
            shift 2  
            ;;  
        -d | --ssd | -ssd)  
	    CHK_SSD=$2  	
            shift 2
	    ;;  
        -h | --help | -help)  
	    usage
	    exit
	    ;;
        -c | --charset | -charset) 
	    case $2 in 
		"utf8") 
	    	   CHK_CHAR=$2
		   shift 2
		   ;;
	    	"utf8mb4")
		   CHK_CHAR=$2
		   shift 2
                   ;;
		*)
	           echo "charset 设置错误"
	    	   usage
		   exit
            esac
	   ;;
	--)
	   usage
	   break
           ;;
        *)   
            echo "Error"
            exit 1  
            ;;  
        esac  
  
done
echo -e "=============your configuration=============\n是否是slave:$CHK_SLAVE\n读写比:$rw_ratio\n是否是ssd:$CHK_SSD\n字符集:$CHK_CHAR\n"
echo -ne "是否继续？请输入\033[31;1m (y/n):\033[0m"
read IF_GOON

if [ $IF_GOON = "y" ];then
#设置server-id
ServerID_Tag=`echo $(hostname) | cut -c3-|sed 's/[-|_]//'`
sed -i 's/^server-id.*/server-id='$ServerID_Tag'/' ./my.cnf
echo "server-id 设置成功!"
#设置字符集
if [  $CHK_CHAR = "utf8" ];then
	sed -i 's/^character_set_server.*/character_set_server=utf8/' ./my.cnf
	sed -i 's/^collation_server.*/collation_server=utf8_general_ci/' ./my.cnf
elif [ $CHK_CHAR = "utf8mb4" ];then
	sed -i 's/^character_set_server.*/character_set_server=utf8mb4/' ./my.cnf
	sed -i 's/^collation_server.*/collation_server=utf8mb4_general_ci/' ./my.cnf
fi

#根据是否是slave，设置read_only
#echo -ne "是否为Slave？请输入\033[31;1m (y/n):\033[0m"
#read CHK_SLAVE
if [ $CHK_SLAVE = "y" ];then
        ReadOnly_Tag=1
elif [ $CHK_SLAVE = "n" ];then
        ReadOnly_Tag=0
else
        echo -e "参数-s设置错误,请输入\033[31;1m y 或者 n,程序退出... \033[0m"
        exit
fi
sed -i 's/^read_only.*/read_only='$ReadOnly_Tag'/' ./my.cnf
echo "read_only设置成功!"
#根据读写比设置innodb_write|read_io_threads
#echo -ne "请输入数据库读写比,\033[31;1m (2:1): \033[0m"
#read rw_ratio
read_rate=`echo $rw_ratio|awk -F: '{print $1}'`
write_rate=`echo $rw_ratio|awk -F: '{print $2}'`
CPU_Unit=`cat /proc/cpuinfo| grep "physical id"| sort| uniq| wc -l`
CPU_Cores_Per_Unit=`cat /proc/cpuinfo| grep "cpu cores"|uniq|awk -F: '{print $2}'`
Total_Cores=$(($CPU_Unit * $CPU_Cores_Per_Unit))
Innodb_Read_Io_Threads_Tag=$(($Total_Cores * $read_rate / ($read_rate+$write_rate)))
Innodb_Write_Io_Threads_Tag=$(($Total_Cores * $write_rate / ($read_rate+$write_rate)))
echo "Innodb_Read_Io_Threads:" $Innodb_Read_Io_Threads_Tag
echo "Innodb_Write_Io_Threads:" $Innodb_Write_Io_Threads_Tag
sed -i 's/^innodb_write_io_threads.*/innodb_write_io_threads='$Innodb_Write_Io_Threads_Tag'/' ./my.cnf
sed -i 's/^innodb_read_io_threads.*/innodb_read_io_threads='$Innodb_Read_Io_Threads_Tag'/' ./my.cnf
echo "innodb_write/read_io_threads设置成功!"
#根据是否为SSD，设置innodb_flush_neighbors
#echo -ne "是否是SSD:\033[31;1m (y/n): \033[0m"
#read CHK_SSD
if [ $CHK_SSD == "y" ];then
        Innodb_Flush_Neighbors_Tag=0
elif [ $CHK_SSD == "n" ];then
        Innodb_Flush_Neighbors_Tag=1
else
        echo -e "参数-d设置错误,请输入\033[31;1m y 或者 n,程序退出... \033[0m"
        exit
fi
sed -i 's/^innodb_flush_neighbors.*/innodb_flush_neighbors='$Innodb_Flush_Neighbors_Tag'/' ./my.cnf
echo "innodb_flush_neighbors设置成功!"
#根据总内存，设置innodb_buffer_pool为3/4
Innodb_Buffer_Pool_Tag=`expr $(free -g|grep "Mem"|awk '{print $2}') \* 3 / 4`
sed -i 's/^innodb_buffer_pool_size.*/innodb_buffer_pool_size='$Innodb_Buffer_Pool_Tag'G/' ./my.cnf
echo "innodb_buffer_pool_size设置成功!"
cp ./my.cnf /etc/my.cnf
echo "my.cnf复制到/etc/下成功!"
#创建用户&用户组
groupadd mysql
useradd -r -g mysql -s /bin/false mysql
echo "mysql用户&用户组创建成功!"
#创建目录&授权
mkdir -p /data/mysql/mysqldata/{binlog,innodb_log,innodb_ts,log,mydata,relaylog,sock,tmpdir,innodb_undo}
chown -R mysql. /data/mysql/mysqldata
echo "/data/mysql/mysqldata/{xxx}目录&权限创建成功!"
#解压->/usr/local & 做软链
echo "现在开始解压安装包到/usr/local/...."
tar zxf mysql-5.7.18-linux-x86_64.tar.gz -C /usr/local/
echo "解压成功!"
cd /usr/local
ln -s mysql-5.7.18-linux-x86_64/ mysql
echo "软链创建成功!"
cd mysql
chown -R mysql. .
echo "现在开始初始化mysql...."
./bin/mysqld --defaults-file=/etc/my.cnf --initialize-insecure
echo -e "mysql初始化成功!\033[31;1m 记得修改root密码！\033[0m"
./bin/mysqld_safe --defaults-file=/etc/my.cnf &
if [ $? = 0 ];then
echo -e "\033[32;1m mysql启动成功\033[0m"
else
echo -e "\033[31;1m mysql启动未成功\033[0m"
fi
cp support-files/mysql.server /etc/init.d/mysql
export PATH=$PATH:/usr/local/mysql/bin
sed -i 's/\(^PATH.*\)/\1:\/usr\/local\/mysql\/bin/' /root/.bash_profile
echo "Successfully Done!Enjoy.. "
else
echo "Bye Bye"
fi
