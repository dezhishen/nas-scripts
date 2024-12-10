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
    i_name=$2
    i_sha256=$3
}

get_volumns(){
    c_name=$1
    i_name=$2
    i_sha256=$3
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

get_iyuu(){
    iyuu_name=$(get_docker_info | grep "iyuucn/iyuuplus-dev")
    if [ "$iyuu_name"x != x ]; then
        echo ${iyuu_name}
        return
    fi
    
    iyuu_name=$(get_docker_info | grep "iyuucn/iyuuplus-")
    if [ "$iyuu_name"x != x ]; then
        echo ${iyuu_name}
        return
    fi
    return
}

iyuu_info=$(get_iyuu)
if [ "$iyuu_info"x != x ]; then
    read -p "iyuu已安装,是否重新安装" yN
    case $yN in
        [Yy]* )
        $(reinstall_iyuu ${iyuu_info})
    ;;
esac
else
    read -p "iyuu未安装,是否安装" yN
    case $yN in
        [Yy]* )
        $(install_iyuu)
    ;;
fi