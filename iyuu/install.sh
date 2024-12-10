#!/bin/bash
set -e
echo "开始iyuu安装程序"

get_docker_info() {
    if [ "$1"x != x ]; then
        get_docker_info | awk '"'$1'"==$1'
        return
    fi
    images=$(docker images --no-trunc)
    for line in $(docker ps | tail -n +2 | awk '{print $NF}'); do
        id=$(docker inspect --format='{{.Image}}' $line | awk -F: '{print $2}')
        echo "$line $(echo "$images" | grep $id | head -n 1)" | tr ':' ' ' | awk '{printf("%s %s %s\n",$1,$2,$5)}'
    done
}

get_docker_network(){
    c_name=$1
}

get_mapping_ports(){
    c_name=$1
}

get_volumns(){
    c_name=$1
}

get_qb(){
    qb_name=$(get_docker_info | grep "linuxserver/qbittorrent")
    if [ "$qb_name"x != x ]; then
        echo ${qb_name}
        return
    fi
    echo "未找到 qbittorrent 容器"
}

get_tr(){
    tr_name=$(get_docker_info | grep "linuxserver/transmission")
    if [ "$tr_name"x != x ]; then
        echo ${tr_name}
        return
    fi
    echo "未找到 transmission 容器"
}

get_qb