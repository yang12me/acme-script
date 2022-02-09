#!/usr/bin/env bash

red(){ echo -e "\033[31m\033[01m$1\033[0m";}
green(){ echo -e "\033[32m\033[01m$1\033[0m";}
yellow(){ echo -e "\033[33m\033[01m$1\033[0m";}
white(){ echo -e "\033[37m\033[01m$1\033[0m";}
[[ $EUID -ne 0 ]] && yellow "请以root模式运行脚本" && exit 1
if [[ -f /etc/redhat-release ]]; then
release="Centos"
elif cat /etc/issue | grep -q -E -i "debian"; then
release="Debian"
elif cat /etc/issue | grep -q -E -i "ubuntu"; then
release="Ubuntu"
elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
release="Centos"
elif cat /proc/version | grep -q -E -i "debian"; then
release="Debian"
elif cat /proc/version | grep -q -E -i "ubuntu"; then
release="Ubuntu"
elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
release="Centos"
else 
red "不支持你当前系统，请选择使用Ubuntu,Debian,Centos系统" && exit 1
fi

get_char(){
SAVEDSTTY=`stty -g`
stty -echo
stty cbreak
dd if=/dev/tty bs=1 count=1 2> /dev/null
stty -raw
stty echo
stty $SAVEDSTTY
}

back(){
white "------------------------------------------------------------------------------------------------"
white " 回主菜单，请按任意键"
white " 退出脚本，请按Ctrl+C"
get_char && bash <(curl -sSL https://cdn.jsdelivr.net/gh/kkkyg/Cscript/ygkkktools.sh)
}

checktls(){
if [[ -f /root/cert.crt && -f /root/private.key ]]; then
if [[ -s /root/cert.crt && -s /root/private.key ]]; then
green "恭喜，域名证书申请成功！域名证书（cert.crt）和私钥（private.key）已保存到 /root 文件夹" 
yellow "证书crt路径如下，可直接复制"
green "/root/cert.crt"
yellow "私钥key路径如下，可直接复制"
green "/root/private.key"
else
red "遗憾，域名证书申请失败"
green "建议如下（按顺序）："
yellow "1、检测防火墙是否打开"
yellow "2、请查看80端口是否被占用（先lsof -i :80 后kill -9 进程id）"
yellow "3、更换下二级域名名称再尝试执行脚本"
fi
fi
}
acme(){
systemctl stop nginx >/dev/null 2>&1
systemctl stop wg-quick@wgcf >/dev/null 2>&1	   
green "安装必要依赖及acme……"
[[ $(type -P yum) ]] && yumapt='yum -y' || yumapt='apt -y'
[[ $(type -P curl) ]] || $yumapt update;$yumapt install curl
[[ $(type -P socat) ]] || $yumapt install socat
[[ $(type -P binutils) ]] || $yumapt install binutils
v6=$(curl -s6m3 https://ip.gs)
v4=$(curl -s4m3 https://ip.gs)
auto=`head -n 50 /dev/urandom | sed 's/[^a-z]//g' | strings -n 4 | tr '[:upper:]' '[:lower:]' | head -1`
curl https://get.acme.sh | sh -s email=$auto@gmail.com
source ~/.bashrc
bash /root/.acme.sh/acme.sh --upgrade --auto-upgrade
yellow "注册acme，创建邮箱的随机前缀：$auto@gmail.com"
read -p "请输入解析完成的域名:" ym
green "已输入的域名:$ym" && sleep 1
domainIP=$(curl -s ipget.net/?ip="cloudflare.1.1.1.1.$ym")
if [[ -n $(echo $domainIP | grep nginx) ]]; then
domainIP=$(curl -s ipget.net/?ip="$ym")
if [[ $domainIP = $v4 ]]; then
yellow "当前二级域名解析到的IPV4：$domainIP" && sleep 1
bash /root/.acme.sh/acme.sh  --issue -d ${ym} --standalone -k ec-256 --server letsencrypt
fi
if [[ $domainIP = $v6 ]]; then
yellow "当前二级域名解析到的IPV6：$domainIP" && sleep 1
bash /root/.acme.sh/acme.sh  --issue -d ${ym} --standalone -k ec-256 --server letsencrypt --listen-v6
fi
if [[ -n $(echo $domainIP | grep nginx) ]]; then
yellow "域名解析无效，请检查二级域名是否填写正确或稍等几分钟等待解析完成再执行脚本"
back
elif [[ -n $(echo $domainIP | grep ":") || -n $(echo $domainIP | grep ".") ]]; then
if [[ $domainIP != $v4 ]] && [[ $domainIP != $v6 ]]; then
red "当前二级域名解析的IP与当前VPS使用的IP不匹配"
green "建议如下："
yellow "1、请确保Cloudflare小黄云关闭状态(仅限DNS)，其他域名解析网站设置同理"
yellow "2、请检查域名解析网站设置的IP是否正确"
back
fi
fi
else
read -p "当前为泛域名申请证书，请复制Cloudflarer的Global API Key:" GAK
export CF_Key="$GAK"
read -p "当前为泛域名申请证书，请输入Cloudflarer的登录邮箱地址:" CFemail
export CF_Email="$CFemail"
if [[ $domainIP = $v4 ]]; then
yellow "当前泛域名解析到的IPV4：$domainIP" && sleep 1
bash /root/.acme.sh/acme.sh --issue --dns dns_cf -d ${ym} -d *.${ym} -k ec-256 --server letsencrypt
fi
if [[ $domainIP = $v6 ]]; then
yellow "当前泛域名解析到的IPV6：$domainIP" && sleep 1
bash /root/.acme.sh/acme.sh --issue --dns dns_cf -d ${ym} -d *.${ym} -k ec-256 --server letsencrypt --listen-v6
fi
fi
bash /root/.acme.sh/acme.sh --install-cert -d ${ym} --key-file /root/private.key --fullchain-file /root/cert.crt --ecc
checktls
systemctl start wg-quick@wgcf >/dev/null 2>&1
back
}

Certificate(){
[[ -z $(acme.sh -v 2>/dev/null) ]] && yellow "未安装acme.sh证书申请，无法执行" && back
bash /root/.acme.sh/acme.sh --list
read -p "请输入要撤销并删除的域名证书（复制Main_Domain下显示的域名）:" ym
if [[ -n $(bash /root/.acme.sh/acme.sh --list | grep $ym) ]]; then
bash /root/.acme.sh/acme.sh --revoke -d ${ym} --ecc
bash /root/.acme.sh/acme.sh --remove -d ${ym} --ecc
green "撤销并删除${ym}域名证书成功"
back
else
red "未找到你输入的${ym}域名证书，请自行核实！"
back
fi
}

acmerenew(){
[[ -z $(acme.sh -v) ]] && yellow "未安装acme.sh证书申请，无法执行" && back
bash /root/.acme.sh/acme.sh --list
read -p "请输入要续期的域名证书（复制Main_Domain下显示的域名）:" ym
if [[ -n $(bash /root/.acme.sh/acme.sh --list | grep $ym) ]]; then
bash /root/.acme.sh/acme.sh --renew -d ${ym} --force --ecc
checktls
back
else
red "未找到你输入的${ym}域名证书，请自行核实！"
back
fi
}

start_menu(){
clear
yellow " 详细说明 https://github.com/kkkyg  YouTube频道：甬哥侃侃侃" 
green " 1.  首次申请证书（自动识别单域名与泛域名） "
green " 2.  查询、撤销并删除当前已申请的域名证书 "
green " 3.  手动续期域名证书 "
green " 0.  退出 "
read -p "请输入数字:" NumberInput
case "$NumberInput" in     
1 ) acme;;
2 ) Certificate;;
3 ) acmerenew;;
0 ) exit 1      
esac
}   
start_menu "first" 
