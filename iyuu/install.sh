#!/bin/bash
set -e
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
    echo $(docker inspect ${c_name} --format '{{ json .NetworkSettings.Networks }}' | awk -F '"' '{print $2}')
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
    # 使用换行符分割，每一行都是一个source:destination
    echo "$(docker inspect --format '{{ range .Mounts }}{{ if eq .Type "bind" }}{{ .Source }}{{ end }}{{ .Name }}:{{ .Destination }}{{ printf "\n" }}{{ end }}' ${c_name} | tr -s '\n' | awk '{for(i=1;i<=NF;i++) print $i}' | tr '\n' ' ')"
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

install_iyuu(){
    iyuu_volumns=$1
    if [ -z "$iyuu_volumns" ]; then
        read -p "输入iyuu自身挂载的目录:" iyuu_volumn_root
        if [ -z "$iyuu_volumn_root" ]; then
            echo "未输入iyuu自身挂载的目录"
            exit 1
        fi
        # 如果结尾是/，则去掉
        if echo "${iyuu_volumn_root}" | grep -q -E "/$"; then
            iyuu_volumn_root="${iyuu_volumn_root%?}"
        fi
        iyuu_volumns="-v ${iyuu_volumn_root}/iyuu:/iyuu -v ${iyuu_volumn_root}/data:/data"
    fi
    echo "iyuu_volumns: ${iyuu_volumns}"
    # 如果安装了qbittorrent，则挂载qbittorrent的所有挂载的目录到/qbittorrent下
    qb_info=$(get_qb)
    if [ -n "$qb_info" ]; then
        volumns=$(get_volumns ${qb_info})
        qb_docker_volumns=""
        for volumn in $volumns; do
            # 使用:分割为source和destination
            source=$(echo ${volumn} | awk -F: '{print $1}')
            destination=$(echo ${volumn} | awk -F: '{print $2}')
            # 拼接为 -v source:/qbittorrent/destination
            qb_docker_volumns="${qb_docker_volumns} -v ${source}:/qbittorrent${destination}"
        done
    fi
    echo "qb_docker_volumns: ${qb_docker_volumns}"
    # 如果安装了transmission，则挂载transmission的所有挂载的目录到/transmission下
    tr_info=$(get_tr)
    if [ -n "$tr_info" ]; then
        volumns=$(get_volumns ${tr_info})
        tr_docker_volumns=""
        for volumn in $volumns; do
            source=$(echo ${volumn} | awk -F: '{print $1}')
            destination=$(echo ${volumn} | awk -F: '{print $2}')
            tr_docker_volumns="${tr_docker_volumns} -v ${source}:/transmission${destination}"
        done
    fi
    docker_comand="docker run --name=iyuu -d --restart=always  --hostname=iyuu -e TZ=Asia/Shanghai -p 8780:8780 \
    ${iyuu_volumns} ${qb_docker_volumns} ${tr_docker_volumns} iyuucn/iyuuplus-dev:latest"
    echo "开始安装iyuu"
    echo "命令: ${docker_comand}"
    read -p "是否执行命令 (y/n):" yN
    case $yN in
        [Yy]* )
            eval ${docker_comand}
        ;;
    esac
}

update_iyuu(){
    iyuu_info=$(get_iyuu)
    if [ -z "$iyuu_info" ]; then
        echo "未安装iyuu"
        exit 1
    fi
    read -p "是否仅更新镜像 (y/n):" yN
    # iyuu的容起名是iyuu_info空格分割的第一个
    iyuu_name=$(echo ${iyuu_info} | awk '{print $1}')
    case $yN in
        [Yy]* )
            # 使用watchtower更新iyuu
            docker run --rm --name watchtower-${name} containrrr/watchtower --clean ${iyuu_name}
        ;;
        [Nn]* )
            # 停止并删除容器
            # 记录 iyuu自身挂载的目录 "/iyuu"和"/data"
            iyuu_volumns=$(get_volumns ${iyuu_info})
            # 逐行处理
            iyuu_final_volumns=""
            for volumn in $iyuu_volumns; do
                # 使用:分割为source和destination
                source=$(echo ${volumn} | awk -F: '{print $1}')
                destination=$(echo ${volumn} | awk -F: '{print $2}')
                # 如果destination是/iyuu或/data，记录
                if [ "${destination}" = "/iyuu" ] || [ "${destination}" = "/data" ]; then
                    iyuu_final_volumns="${iyuu_final_volumns} -v ${source}:${destination}"
                fi
            done
            echo "保留挂载卷: ${iyuu_final_volumns}"
            echo "停止旧的容器"
            docker stop ${iyuu_name}
            docker rm ${iyuu_name}
            # 此处iyuu_final_volumns带有空格，使用"包裹
            install_iyuu "${iyuu_final_volumns}"
        ;;
    esac
}

install_qbittorrent(){
    echo "todo 安装qbittorrent"
}

install_transmission(){
    echo "todo 安装transmission"
}


echo "开始iyuu安装程序"
mkdir -p ".args"

qbittorrent_info=$(get_qb)
if [ -z "$qbittorrent_info" ]; then
    echo "未安装qbittorrent"
else
    echo "已安装qbittorrent"
    echo "【目录挂载】: \n$(get_volumns ${qbittorrent_info})"
    echo "【网络模式】: \n$(get_docker_network ${qbittorrent_info})"
    echo "【端口映射】: \n$(get_mapping_ports ${qbittorrent_info})"
fi

transmission_info=$(get_tr)
if [ -z "$transmission_info" ]; then
    echo "未安装transmission"
else
    echo "已安装transmission"
    echo "【目录挂载】: \n$(get_volumns ${transmission_info})"
    echo "【网络模式】: \n$(get_docker_network ${transmission_info})"
    echo "【端口映射】: \n$(get_mapping_ports ${transmission_info})"
fi

if [ -z "${qbittorrent_info}${transmission_info}" ]; then
    read -p "未找到任何下载器，是否安装 (y/n):" yN
    case $yN in
        [Yy]* ) 
            echo "[0]安装qbittorrent"
            echo "[1]安装transmission"
            read -p "请输入序号，进行下载器的安装:" seq
            if [ "${seq}" = "0" ]; then
                install_qbittorrent
            elif [ "${seq}" = "1" ];then
                install_transmission
            fi
        ;;
    esac
fi

echo "获取iyuu信息"
iyuu_info=$(get_iyuu)
if [ -z "$iyuu_info" ]; then
    read -p "iyuu未安装,是否安装 (y/n):" yN
    case $yN in
        [Yy]* )
            install_iyuu
        ;;
    esac
else
    read -p "iyuu已安装,是否更新 (y/n):" yN
    case $yN in
        [Yy]* )
            update_iyuu
        ;;
    esac
fi