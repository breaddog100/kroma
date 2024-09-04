#!/bin/bash

# 设置版本号
current_version=20240904001

update_script() {
    # 指定URL
    update_url="https://raw.githubusercontent.com/breaddog100/kroma/main/kroma.sh"
    file_name=$(basename "$update_url")

    # 下载脚本文件
    tmp=$(date +%s)
    timeout 10s curl -s -o "$HOME/$tmp" -H "Cache-Control: no-cache" "$update_url?$tmp"
    exit_code=$?
    if [[ $exit_code -eq 124 ]]; then
        echo "命令超时"
        return 1
    elif [[ $exit_code -ne 0 ]]; then
        echo "下载失败"
        return 1
    fi

    # 检查是否有新版本可用
    latest_version=$(grep -oP 'current_version=([0-9]+)' $HOME/$tmp | sed -n 's/.*=//p')

    if [[ "$latest_version" -gt "$current_version" ]]; then
        clear
        echo ""
        # 提示需要更新脚本
        printf "\033[31m脚本有新版本可用！当前版本：%s，最新版本：%s\033[0m\n" "$current_version" "$latest_version"
        echo "正在更新..."
        sleep 3
        mv $HOME/$tmp $HOME/$file_name
        chmod +x $HOME/$file_name
        exec "$HOME/$file_name"
    else
        # 脚本是最新的
        rm -f $tmp
    fi

}

# 安装全节点
function install_full_node(){
    # 更新系统
	sudo apt update
	sudo apt install -y git

    # 检查是否安装了Docker
	if ! command -v docker &> /dev/null; then
	    echo "Docker未安装，正在安装..."
	    # 更新包列表
	    sudo apt-get update
	    # 安装必要的包
	    sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
	    # 添加Docker的官方GPG密钥
	    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/docker.gpg
	    # 添加Docker的APT仓库
	    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
	    # 再次更新包列表
	    sudo apt-get update
	    # 安装Docker
	    sudo apt-get install -y docker-ce
	    echo "Docker安装完成。"
	else
	    echo "Docker已安装。"
	fi
	
	sudo groupadd docker
	sudo usermod -aG docker $USER

    git clone https://github.com/kroma-network/kroma-up.git
    cd kroma-up

    # 初始化
    ./startup.sh sepolia

    sudo docker compose -f docker-compose-sepolia.yml --profile fullnode up -d
    echo "全节点部署完成..."
}

# 安装验证节点
function install_validator_node(){

    # 输入参数
    read -p "ETH钱包私钥，钱包中需要有0.2eth作为押金: " YOUR_ETH_PRIVATE_KEY

    # 更新系统
	sudo apt update
	sudo apt install -y git

    # 检查是否安装了Docker
	if ! command -v docker &> /dev/null; then
	    echo "Docker未安装，正在安装..."
	    # 更新包列表
	    sudo apt-get update
	    # 安装必要的包
	    sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
	    # 添加Docker的官方GPG密钥
	    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/docker.gpg
	    # 添加Docker的APT仓库
	    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
	    # 再次更新包列表
	    sudo apt-get update
	    # 安装Docker
	    sudo apt-get install -y docker-ce
	    echo "Docker安装完成。"
	else
	    echo "Docker已安装。"
	fi
	
	sudo groupadd docker
	sudo usermod -aG docker $USER

    git clone https://github.com/kroma-network/kroma-up.git
    cd kroma-up

    # 初始化
    ./startup.sh sepolia

    # 修改参数
    cd kroma-up
    sed -i "s/^KROMA_VALIDATOR__PRIVATE_KEY=.*/KROMA_VALIDATOR__PRIVATE_KEY=${YOUR_ETH_PRIVATE_KEY}/" .env
    sed -i "s/^KROMA_VALIDATOR__OUTPUT_SUBMITTER_ENABLED=.*/KROMA_VALIDATOR__OUTPUT_SUBMITTER_ENABLED=true/" .env
    sed -i "s/^KROMA_VALIDATOR__CHALLENGER_ENABLED=.*/KROMA_VALIDATOR__CHALLENGER_ENABLED=false/" .env

    # 启动证明客户端
    ./setup_prover.sh

    # 启动验证者
    sudo docker compose -f docker-compose-sepolia.yml --profile fullnode up -d

    # 存入 ValidatorPool
    # 为了使您的验证者节点能够提交检查点输出或挑战，您需要将一定数量的以太坊存入 ValidatorPool，
    # 作为每次输出提交的保证金。每次输出提交的保证金金额为 0.2 ETH。
    sudo docker exec kroma-validator kroma-validator deposit --amount 100000000000000000 #(unit:wei)
    
    echo "验证节点部署完成..."
}

# 检查 kroma-prover 客户端是否已成功启动
# sudo docker compose -f docker-compose-sepolia.yml logs -f kroma-prover

# 卸载节点
function uninstall_node(){
    echo "你确定要卸载节点程序吗？这将会删除所有相关的数据。[Y/N]"
    read -r -p "请确认: " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            read -p "节点名称: " NODE_NAME
            echo "开始卸载节点程序..."
            sudo docker rm -f $NODE_NAME
            echo "节点程序卸载完成。"
            ;;
        *)
            echo "取消卸载操作。"
            ;;
    esac
}

# 主菜单
function main_menu() {
	while true; do
	    clear
	    echo "===================kroma 一键部署脚本==================="
		echo "当前版本：$current_version"
		echo "沟通电报群：https://t.me/lumaogogogo"
	    echo "请选择要执行的操作:"
	    echo "1. 安装全节点 install_full_node"
        echo "2. 安装验证节点 install_validator_node"
        echo "3. 停止节点 stop_node"
	    echo "4. 节点日志 logs_node"
        echo "5. 块高度 check_block"
        echo "6. 节点日志 logs_node"
        echo "1618. 卸载节点 uninstall_node"
	    echo "0. 退出脚本 exit"
	    read -p "请输入选项: " OPTION
	
	    case $OPTION in
	    1) install_node ;;
        2) start_node ;;
        3) stop_node ;;
	    4) logs_node ;;
        5) check_block ;;
        6) logs_node ;;
        1618) uninstall_node ;;
	    0) echo "退出脚本。"; exit 0 ;;
	    *) echo "无效选项，请重新输入。"; sleep 3 ;;
	    esac
	    echo "按任意键返回主菜单..."
        read -n 1
    done
}

# 检查更新
update_script

# 显示主菜单
main_menu