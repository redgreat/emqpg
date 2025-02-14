#!/bin/sh

set -x

RELX_CONFIG_PATH=/opt/emqpg/config/sys.config
VMARGS_PATH=/opt/emqpg/config/vm.args

export VMARGS_PATH RELX_CONFIG_PATH

# 用户ID/组ID定义
USER_ID=`stat -c '%u' /opt/emqpg/config/db.config`
GROUP_ID=`stat -c '%g' /opt/emqpg/config/db.config`
USER_ID=$([ "$USER_ID" = "0" ] && echo -n "1000" || echo -n "$USER_ID")
GROUP_ID=$([ "$GROUP_ID" = "0" ] && echo -n "1000" || echo -n "$GROUP_ID")

# 初始化时创建用户
if id "emqpg" &>/dev/null
then
    echo "found user emqpg"
else
    echo "create user emqpg"
    addgroup -S -g $GROUP_ID eadm
    adduser -S -D -u $USER_ID -G emqpg emqpg
fi

# 创建文件夹
mkdir -p /opt/emqpg/log && chown -R emqpg:emqpg /opt/emqpg

# 前台运行
exec /usr/bin/gosu emqpg /opt/emqpg/bin/emqpg foreground
