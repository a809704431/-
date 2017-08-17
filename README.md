# -
MySQL一键安装脚本

## 使用方法

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
