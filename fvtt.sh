#!/bin/bash

# FoundryVTT 安装脚本默认参数

# 容器名
fvttname="fvtt"
caddyname="caddy"
fbname="filebr"

# 网桥/挂载名
bridge="caddy_network"
fvttvolume="fvtt_data"
caddyvolume="caddy_data"

# 端口号（无域名使用）
fvttport="30000"
fbport="30001"

# 杂项，此处直接使用 PWD 有一定风险
caddyfile="$PWD/Caddyfile"  # Caddy 配置
fbdatabase="$PWD/filebrowser.db" # FileBrowser 数据库

# 以下为 cecho, credit to Tux
# ---------------------
cecho() {
    declare -A colors;
    colors=(\
        ['black']='\E[0;47m'\
        ['red']='\E[0;31m'\
        ['green']='\E[0;32m'\
        ['yellow']='\E[0;33m'\
        ['blue']='\E[0;34m'\
        ['magenta']='\E[0;35m'\
        ['cyan']='\E[0;36m'\
        ['white']='\E[0;37m'\
    );
 
    local defaultMSG="无消息";
    local defaultColor="black";
    local defaultNewLine=true;

    while [[ $# -gt 1 ]];
    do
    key="$1";
 
    case $key in
        -c|--color)
            color="$2";
            shift;
        ;;
        -n|--noline)
            local newLine=false;
        ;;
        *)
            # unknown option
        ;;
    esac
    shift;
    done
 
    message=${1:-$defaultMSG};   # Defaults to default message.
    color=${color:-$defaultColor};   # Defaults to default color, if not specified.
    newLine=${newLine:-$defaultNewLine};
 
    echo -en "${colors[$color]}";
    echo -en "$message";
    if [ "$newLine" = true ] ; then
        echo;
    fi
    tput sgr0; #  Reset text attributes to normal without clearing screen.
 
    return;
}

warning() {
    cecho -c 'yellow' "$@";
}
 
error() {
    cecho -c 'red' "$@";
}
 
information() {
    cecho -c 'blue' "$@";
}

success() {
    cecho -c 'green' "$@";
}

echoLine() {
    cecho -c 'cyan' "========================"
}
# ---------------------

# FoundryVTT 容器化自动安装脚本
# By hmqgg (https://github.com/hmqgg)

cecho -c 'magenta' "FoundryVTT 容器化自动安装脚本"
cecho -c 'magenta' "By hmqgg (https://github.com/hmqgg)"
echoLine

# 检查 Root 权限
[ "$EUID" -ne 0 ] && error "错误：请使用 root 账户或 sudo 命令执行脚本" && exit 1

# 安装（默认步骤），或重建
if test -z "$@" || test "$@" == "recreate"; then

# 第一步，检查 Docker 安装
if [ -x "$(command -v docker)" ]; then
    information "Docker 已安装"
else
    warning "Docker 未安装，安装中...（境内服务器可能较慢，耐心等待）"
    curl -fsSL https://get.docker.com | sh
fi

# 安装后，仍需检查
[ ! -x "$(command -v docker)" ] && exit $?

# 确认 Docker 是否能启动容器，以 hello-world 镜像尝试
if ! docker run --rm hello-world; then
    error "错误：Docker 无法启动容器，请联系脚本作者"
    exit 2
fi

information "运行环境检查完毕无误"
echoLine

# 第二步，输入可配置参数
# 密码回显，方便初学者
warning "请输入以下参数，用于获取 FoundryVTT 下载链接及授权，并配置服务器"

while read -p "请输入已购买的 FoundryVTT 账号：" username && [ -z "$username" ] || read -p "请输入密码：" password && [ -z "$password" ]; do
    error "错误：请输入有效的账号密码！"
done
echoLine

# 可选参数。若有域名，则使用 Caddy 反代
read -p "请输入要安装的 FoundryVTT 的版本号【例：0.6.5】（可选。若无，直接回车，默认使用最新稳定版）：" version
read -p "请输入自定义的 FoundryVTT 的管理密码（可选。若无，直接回车）：" adminpass
read -p "请输入 FoundryVTT 将会使用的已绑定该服务器的域名（可选。若无，直接回车）：" domain
read -p "是否使用 Web 文件管理器来管理 FoundryVTT 的文件?（可选。推荐使用，默认开启）[Y/n]：" fbyn
[ "$fbyn" != "n" -a "$fbyn" != "N" ] && read -p "请输入 Web 文件管理器将会使用的已绑定该服务器的域名（可选。若无，直接回车）：" fbdomain
echoLine

warning "请确认以下所有参数是否输入正确！！！"
information -n "FVTT 账号：" && cecho -c 'cyan' $username
information -n "FVTT 密码：" && cecho -c 'cyan' $password
[ -n "$version" ] && information -n "FVTT 安装版本：" && cecho -c 'cyan' $version
[ -n "$adminpass" ] && information -n "FVTT 管理密码：" && cecho -c 'cyan' $adminpass
[ -n "$domain" ] && information -n "FVTT 域名：" && cecho -c 'cyan' $domain
information -n "Web 文件管理器：" && [ "$fbyn" != "n" -a "$fbyn" != "N" ] && cecho -c 'cyan' "启用" || cecho -c 'cyan' "禁用"
[ -n "$fbdomain" ] && information -n "Web 文件管理器域名：" && cecho -c 'cyan' $fbdomain

read -s -p "按下回车确认参数正确，否则按下 Ctrl+C 退出"
echo
echoLine

# 第三步，拉取镜像
information "拉取需要使用到的镜像（境内服务器可能较慢，耐心等待）"

docker pull felddy/foundryvtt:release && docker image inspect felddy/foundryvtt:release >/dev/null 2>&1 && success "拉取 FoundryVTT 成功" || { error "错误：拉取 FoundryVTT 失败" ; exit 3 ; }
docker pull caddy && docker image inspect caddy >/dev/null 2>&1 && success "拉取 Caddy 成功" || { error "错误：拉取 Caddy 失败" ; exit 3 ; }
if [ "$fbyn" != "n" -a "$fbyn" != "N" ]; then
    docker pull filebrowser/filebrowser && docker image inspect filebrowser/filebrowser >/dev/null 2>&1 && success "拉取 FileBrowser 成功" || { error "错误：拉取 FileBrowser 失败" ; exit 3 ; }
fi

# 第四步，开始部署
# 创建网桥和挂载
docker network create $bridge || { error "错误：创建网桥失败。通常是因为已经创建，请升级而非安装" ; exit 4 ; }
docker volume create $fvttvolume || warning "警告：创建挂载 ${fvttvolume} 失败。通常是因为已经创建，如果正在升级，请无视该警告"
docker volume create $caddyvolume || warning "警告：创建挂载 ${caddyvolume} 失败。通常是因为已经创建，如果正在升级，请无视该警告"

# 检查是否有同名容器
docker container inspect $fvttname >/dev/null 2>&1 && error "错误：FoundryVTT 已经启动过，请升级而非安装" && exit 5
docker container inspect $caddyname >/dev/null 2>&1 && error "错误：Caddy 已经启动过，请升级而非安装" && exit 5
[ "$fbyn" != "n" -a "$fbyn" != "N" ] && docker container inspect $fbname >/dev/null 2>&1 && error "错误：FileBrowser 已经启动过，请升级而非安装" && exit 5

success "网桥、挂载创建成功，且无同名容器"
echoLine

# 重写 Caddy 配置
if [ -n "$domain" ]; then
    # 有域名
cat <<EOF >$caddyfile
$domain {
    reverse_proxy ${fvttname}:30000 {
        header_up Host {host}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}  
    }
}

EOF
else
    # 无域名
cat <<EOF >$caddyfile
:${fvttport} {
    reverse_proxy ${fvttname}:30000 {
        header_up Host {host}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}  
    }
}

EOF
fi

# FileBrowser
if [ "$fbyn" != "n" -a "$fbyn" != "N" ]; then
    if [ -n "$fbdomain" ]; then
cat <<EOF >>$caddyfile
$fbdomain {
    reverse_proxy ${fbname}:80
}

EOF
    else
cat <<EOF >>$caddyfile
:${fbport} {
    reverse_proxy ${fbname}:80
}

EOF
    fi
fi

cat $caddyfile 2>/dev/null && success "Caddy 配置成功" || { error "错误：无法读取 Caddy 配置文件" ; exit 6 ; }
echoLine

# 启动容器
# Caddy
caddyrun="docker run -d --name=${caddyname} --restart=unless-stopped --network=${bridge} -v ${caddyvolume}:/data -v ${caddyfile}:/etc/caddy/Caddyfile -p ${fvttport}:${fvttport} -p ${fbport}:${fbport} "
[ -n "$domain" -o -n "$fbdomain" ] && caddyrun="${caddyrun}-p 80:80 -p 443:443 "
caddyrun="${caddyrun}caddy"
eval $caddyrun && docker container inspect $caddyname >/dev/null 2>&1 && success "Caddy 容器启动成功" || { error "错误：Caddy 容器启动失败" ; exit 7 ; }

# FVTT
fvttrun="docker run -d --name=${fvttname} --restart=unless-stopped --network=${bridge} -v ${fvttvolume}:/data -e FOUNDRY_USERNAME='${username}' -e FOUNDRY_PASSWORD='${password}' "
[ -n "$version" ] && fvttrun="${fvttrun}-e FOUNDRY_VERSION=${version} "
[ -n "$adminpass" ] && fvttrun="${fvttrun}-e FOUNDRY_ADMIN_KEY=${adminpass} "
fvttrun="${fvttrun} felddy/foundryvtt:release"
eval $fvttrun && docker container inspect $fvttname >/dev/null 2>&1 && success "FoundryVTT 容器启动成功" || { error "错误：FoundryVTT 容器启动失败" ; exit 7 ; }

# FileBrowser
if [ "$fbyn" != "n" -a "$fbyn" != "N" ]; then
    # 提前创建/清空数据库，但只在安装过程中
    [ -z "$@" ] && truncate -s 0 $fbdatabase
    fbrun="docker run -d --name=${fbname} --restart=unless-stopped --network=${bridge} -v ${fvttvolume}:/srv -v ${fbdatabase}:/database.db filebrowser/filebrowser"
    eval $fbrun && docker container inspect $fbname >/dev/null 2>&1 && success "FileBrowser 容器启动成功" || { error "FileBrowser 容器启动失败" ; exit 7 ; }
fi
echoLine

# 成功，列出访问方式
success "FoundryVTT 已成功部署！服务器设定如下："
echoLine
information -n "FoundryVTT 访问地址： " && [ -n "$domain" ] && cecho -c 'cyan' $domain || cecho -c 'cyan' "服务器IP:${fvttport}"
[ -n "$adminpass" ] && information -n "FVTT 管理密码：" && cecho -c 'cyan' $adminpass
if [ "$fbyn" != "n" -a "$fbyn" != "N" ]; then
    information -n "Web 文件管理器访问地址： " && [ -n "$fbdomain" ] && cecho -c 'cyan' $fbdomain || cecho -c 'cyan' "服务器IP:${fbport}"
    # Web 文件管理器的用户名/密码可能在数据库里被修改
    [ -z "$@" ] && information -n "Web 文件管理器用户名/密码: " && cecho -c 'cyan' "admin/admin （建议登录后修改）"
fi
echoLine
fi

recreate() {
    # 空，进安装流程
}

remove() {
    error -n "警告！！！使用该命令将删除所有容器和网桥，但是存档、文件等数据将保留，不过仍可能导致意外后果！" && read -p "[Y/n]：" rmyn
    if [ "$rmyn" == "y" -o "$rmyn" == "Y" ]; then
        warning "删除中...（等待5秒，按下 Ctrl+C 立即中止）"
        sleep 3

        # 移除容器
        docker rm -f $fvttname
        docker rm -f $caddyname
        docker rm -f $filebr

        # 移除网桥
        docker network rm $bridge

        success "删除完毕！"
    fi
}

restart() {
    error -n "警告！！！使用该命令将重启所有容器，可能导致意外后果！" && read -p "[Y/n]：" restartyn
    if [ "$restartyn" == "y" -o "$restartyn" == "Y" ]; then
        warning "重启中...（等待5秒，按下 Ctrl+C 立即中止）"
        sleep 3

        docker restart fvtt
        docker restart filebr
        docker restart caddy

        success "重启完毕！"
    fi
}

clear() {
    error -n "警告！！！使用该命令将清除所有内容，包括 Caddy、 FVTT 所有游戏、存档、文件！" && read -p "[Y/n]：" cleanyn && [ "$cleanyn" == "y" -o "$cleanyn" == "Y" ] && \
     error -n "再次警告！！！使用该命令将清除所有内容，包括 Caddy、 FVTT 所有游戏、存档、文件！" && read -p "[Y/n]：" cleanyn
    if [ "$cleanyn" == "y" -o "$cleanyn" == "Y" ]; then
        warning "清除中...（等待5s，按下 Ctrl+C 立即中止）"
        sleep 3

        # 移除容器
        docker rm -f $fvttname
        docker rm -f $caddyname
        docker rm -f $filebr

        # 移除网桥、挂载
        docker network rm $bridge
        docker volume rm $caddyvolume $fvttvolume

        # 删除创建的文件
        rm $caddyfile $fbdatabase

        success "清除完毕！"
    fi
}

"$@"

echo