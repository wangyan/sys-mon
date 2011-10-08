#! /bin/bash
#====================================================================
# sys-mon.sh
#
# Copyright (c) 2011, WangYan <webmaster@wangyan.org>
# All rights reserved.
# Distributed under the GNU General Public License, version 3.0.
#
# Monitor system mem and load, if too high, restart some service.
#
# See: https://wangyan.org/blog/sys-mon-shell-script.html
#
# V0.3, since 2011-09-14
#====================================================================

# Need to monitor the service name
NAME_LIST="php-fpm mysql nginx"

# Single process to allow the maximum CPU (%)
PID_CPU_MAX="20"

# The maximum allowed memory (%)
SYS_MEM_MAX="90"

# The maximum allowed system load
SYS_LOAD_MAX="5"

# Log path settings
LOG_PATH="/var/log/autoreboot.log"

# Date time format setting
DATA_TIME=$(date +"%y-%m-%d %H:%M:%S")

# Your email address
EMAIL="webmaster@wangyan.org"

# Your website url
MY_URL="https://wangyan.org/blog"

#====================================================================

for NAME in $NAME_LIST
do
SYS_CPU_SUM="0";SYS_MEM_SUM="0"
    PID_LIST=`ps aux | grep $NAME | grep -v root`

    IFS_TMP="$IFS";IFS=$'\n'
    for PID in $PID_LIST
    do
PID_NUM=`echo $PID | awk '{print $2}'`
        PID_CPU=`echo $PID | awk '{print $3}'`
        PID_MEM=`echo $PID | awk '{print $4}'`
# echo $NAME: $PID_NUM $PID_CPU $PID_MEM

# SYS_CPU_SUM=`echo $SYS_CPU_SUM + $PID_CPU | bc`
        SYS_MEM_SUM=`echo $SYS_MEM_SUM + $PID_MEM | bc`

        if [[ "$NAME" = "php-fpm" && "$PID_CPU" > "$PID_CPU_MAX" ]];then
echo "$DATA_TIME kill $PID_NUM successful (CPU:$PID_CPU)" | tee -a $LOG_PATH
            kill $PID_NUM
        fi
done
IFS="$IFS_TMP"

    SYS_LOAD=`uptime | awk '{print $(NF-2)}' | sed 's/,//'`
    MEM_COMPARE=`awk 'BEGIN{print('$SYS_MEM_SUM'>'$SYS_MEM_MAX')}'`
    LOAD_COMPARE=`awk 'BEGIN{print('$SYS_LOAD'>'$SYS_LOAD_MAX')}'`
# echo -e "$NAME: CPU_SUM:$SYS_CPU_SUM MEM_SUM:$SYS_MEM_SUM SYS_LOAD:$SYS_LOAD\n"

    for ((i=0;i<3;i++))
    do
STATUS_CODE=`curl -o /dev/null -s -w %{http_code} $MY_URL`
        if [ "$STATUS_CODE" = "200" ];then
break
fi
done

if [[ "$MEM_COMPARE" = "1" || "$LOAD_COMPARE" = "1" || "$STATUS_CODE" = "502" ]];then
        /etc/init.d/$NAME stop
        if [ "$?" = "0" ];then
echo "$DATA_TIME Stop $NAME successful (MEM:$SYS_MEM_SUM CPU:$SYS_CPU_SUM LOAD:$SYS_LOAD)" | tee -a $LOG_PATH
        else
echo "$DATA_TIME Stop $NAME [failed] (MEM:$SYS_MEM_SUM CPU:$SYS_CPU_SUM LOAD:$SYS_LOAD)" | tee -a $LOG_PATH
            sleep 3
            pkill $NAME
        fi
        /etc/init.d/$NAME start
        if [ "$?" = "0" ];then
echo "$DATA_TIME Start $NAME successful" | tee -a $LOG_PATH
        else
echo "$DATA_TIME Start $NAME [failed]" | tee -a $LOG_PATH
            echo "$DATA_TIME Start $NAME failed" | mail -s "Start $NAME failed" $EMAIL
        fi
fi

done
