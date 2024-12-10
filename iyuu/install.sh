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
    i_name=$2
    i_sha256=$3
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
    qb_info=$(get_docker_info | grep "linuxserver/qbittorrent" |tr -s '\n')
    if [ "$qb_info"x != x ]; then
        echo ${qb_info}
        return
    fi
}

get_tr(){
    tr_info=$(get_docker_info | grep "linuxserver/transmission" |tr -s '\n')
    if [ "$tr_info"x != x ]; then
        echo ${tr_info}
        return
    fi
}

get_iyuu(){
    iyuu_info=$(get_docker_info | grep "iyuucn/iyuuplus-dev" |tr -s '\n' )
    if [ "$iyuu_info"x != x ]; then
        echo ${iyuu_info}
        return
    fi
    
    iyuu_info=$(get_docker_info | grep "iyuucn/iyuuplus" |tr -s '\n' )
    if [ "$iyuu_info"x != x ]; then
        echo ${iyuu_info}
        return
    fi
    return
}

echo "获取qbittorrent信息"
qbittorrent_info=$(get_qb)
if [ -z "$qbittorrent_info" ]; then
    echo "未安装qbittorrent"
else
    echo "已安装qbittorrent"
fi

echo "获取transmission信息"
transmission_info=$(get_tr)
if [ -z "$transmission_info" ]; then
    echo "未安装transmission"
else
    echo "已安装transmission"
fi

if [ -z "${qbittorrent_info}${transmission_info}" ]; then
    echo "未找到任何下载器"
    exit 1
fi

echo "获取iyuu信息"
iyuu_info=$(get_iyuu)
if [ -z "$iyuu_info" ]; then
    read -p "iyuu未安装,是否安装 (y/n):" yN
    case $yN in
        [Yy]* )
        $(install_iyuu)
    ;;
    esac
else
    read -p "iyuu已安装,是否更新 (y/n):" yN
    case $yN in
        [Yy]* )
        $(update_iyuu)
    ;;
    esac
fi