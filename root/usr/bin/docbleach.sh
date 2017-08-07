#!/bin/ash
. /usr/share/libubox/jshn.sh

TASK=$(curl -s -F "file=@$1" https://www.docbleach.xyz/v1/tasks)

json_init
json_load "$TASK"
json_get_vars task_id task_id

status="PENDING"
while [ "$status" != "SUCCESS" ]; do
        _=$(wget -qO- https://www.docbleach.xyz/v1/tasks/${task_id})
        json_load "$_"
        json_get_vars status status
        [ "${status}" != "SUCCESS" ] && lua -l socket -e "socket.select(nil, nil, 0.1)";
done

echo $_
exit 0

