#!/bin/bash

# 署名和说明
cat << "EOF"

   __   _         _                                    ___    _  _   
  / _| (_)       | |                                  |__ \  | || |  
 | |_   _   ___  | |__    ____   ___    _ __     ___     ) | | || |_ 
 |  _| | | / __| | '_ \  |_  /  / _ \  | '_ \   / _ \   / /  |__   _|
 | |   | | \__ \ | | | |  / /  | (_) | | | | | |  __/  / /_     | |  
 |_|   |_| |___/ |_| |_| /___|  \___/  |_| |_|  \___| |____|    |_|  
                                                                     
                                                                     

EOF

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色
RESET=$NC

echo -e "${BLUE}==================================================================${RESET}"
echo -e "${GREEN}Parasail-Bot一键管理脚本${RESET}"
echo -e "${YELLOW}脚本作者: fishzone24 - 推特: https://x.com/fishzone24${RESET}"
echo -e "${YELLOW}此脚本为免费开源脚本，如有问题请提交 issue${RESET}"
echo -e "${BLUE}==================================================================${RESET}"

# 打印带颜色的信息
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否有root权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "请使用root权限运行此脚本"
        exit 1
    fi
}

# 安装jq命令（用于解析JSON）
install_jq() {
    if ! command -v jq &> /dev/null; then
        print_info "正在安装jq..."
        apt update
        apt install -y jq
    fi
}

# 更新系统并安装所需依赖
install_dependencies() {
    print_info "正在更新系统并安装所需依赖..."
    apt update -y
    apt upgrade -y
    apt install -y curl wget git nodejs npm
    
    # 检查Node.js版本，如果低于14则更新
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node -v | cut -d 'v' -f 2 | cut -d '.' -f 1)
        if [ "$NODE_VERSION" -lt 14 ]; then
            print_warn "Node.js版本低于14，正在更新..."
            curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
            apt install -y nodejs
        fi
    else
        print_warn "未检测到Node.js，正在安装..."
        curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
        apt install -y nodejs
    fi
    
    print_info "依赖安装完成"
}

# 克隆项目仓库
clone_repository() {
    print_info "正在克隆项目仓库..."
    
    if [ -d "Parasail-Bot" ]; then
        print_warn "检测到已存在的项目目录，正在更新..."
        cd Parasail-Bot
        git pull
        cd ..
    else
        git clone https://github.com/Gzgod/Parasail-Auto-Bot.git Parasail-Bot
        cd Parasail-Bot
        npm install
        cd ..
    fi
    
    print_info "仓库克隆/更新完成"
}

# 配置代理
configure_proxy() {
    print_info "正在配置代理功能..."
    
    cd Parasail-Bot
    
    # 备份原始index.js
    if [ ! -f "index.js.original" ]; then
        cp index.js index.js.original
    fi
    
    # 创建代理配置文件 (新格式，不包含accounts数组)
    cat > proxy_config.json << EOL
EOL
    
    # 修改index.js文件，添加代理支持
    sed -i 's/const axios = require('"'"'axios'"'"');/const axios = require('"'"'axios'"'"');\nconst { HttpsProxyAgent } = require('"'"'https-proxy-agent'"'"');\nconst { SocksProxyAgent } = require('"'"'socks-proxy-agent'"'"');/' index.js
    
    # 在ParasailNodeBot构造函数中添加代理支持
    sed -i 's/constructor(account, index, screen) {/constructor(account, index, screen, proxy = null) {\n    this.proxy = proxy;/' index.js
    
    # 修改axios请求以使用代理（支持HTTP/HTTPS和SOCKS5）
    sed -i 's/const response = await axios.post(`${this.baseUrl}\/user\/verify`, signatureData, {/const axiosConfig = {\n      headers: {\n        '"'"'Accept'"'"': '"'"'application\/json, text\/plain, *\/*'"'"',\n        '"'"'Content-Type'"'"': '"'"'application\/json'"'"'\n      }\n    };\n\n    if (this.proxy) {\n      let proxyAgent;\n      if (this.proxy.startsWith('"'"'socks5:'"'"')) {\n        proxyAgent = new SocksProxyAgent(this.proxy);\n        this.log(`Using SOCKS5 proxy: ${this.proxy}`);\n      } else {\n        proxyAgent = new HttpsProxyAgent(this.proxy);\n        this.log(`Using HTTP/HTTPS proxy: ${this.proxy}`);\n      }\n      axiosConfig.httpsAgent = proxyAgent;\n      axiosConfig.httpAgent = proxyAgent;\n    }\n\n    const response = await axios.post(`${this.baseUrl}\/user\/verify`, signatureData, axiosConfig/' index.js
    
    # 修改所有其他axios请求以支持代理
    sed -i 's/const response = await axios.get(`${this.baseUrl}\/v1\/node\/node_stats`, {/const axiosConfig = {\n      params: { address: this.config.wallet_address },\n      headers: {\n        '"'"'Authorization'"'"': `Bearer ${this.config.bearer_token}`,\n        '"'"'Accept'"'"': '"'"'application\/json, text\/plain, *\/*'"'"'\n      }\n    };\n\n    if (this.proxy) {\n      let proxyAgent;\n      if (this.proxy.startsWith('"'"'socks5:'"'"')) {\n        proxyAgent = new SocksProxyAgent(this.proxy);\n      } else {\n        proxyAgent = new HttpsProxyAgent(this.proxy);\n      }\n      axiosConfig.httpsAgent = proxyAgent;\n      axiosConfig.httpAgent = proxyAgent;\n    }\n\n    const response = await axios.get(`${this.baseUrl}\/v1\/node\/node_stats`, axiosConfig/' index.js
    
    # 修改checkIn和onboardNode方法以支持代理
    sed -i 's/const checkInResponse = await axios.post(/const checkInConfig = {\n      headers: {\n        '"'"'Authorization'"'"': `Bearer ${this.config.bearer_token}`,\n        '"'"'Content-Type'"'"': '"'"'application\/json'"'"',\n        '"'"'Accept'"'"': '"'"'application\/json, text\/plain, *\/*'"'"'\n      }\n    };\n\n    if (this.proxy) {\n      let proxyAgent;\n      if (this.proxy.startsWith('"'"'socks5:'"'"')) {\n        proxyAgent = new SocksProxyAgent(this.proxy);\n      } else {\n        proxyAgent = new HttpsProxyAgent(this.proxy);\n      }\n      checkInConfig.httpsAgent = proxyAgent;\n      checkInConfig.httpAgent = proxyAgent;\n    }\n\n    const checkInResponse = await axios.post(/' index.js
    
    sed -i 's/`${this.baseUrl}\/v1\/node\/check_in`, \n        { address: this.config.wallet_address },\n        {/`${this.baseUrl}\/v1\/node\/check_in`, \n        { address: this.config.wallet_address },\n        checkInConfig/' index.js
    
    sed -i 's/const response = await axios.post(`${this.baseUrl}\/v1\/node\/onboard`, /const onboardConfig = {\n      headers: {\n        '"'"'Authorization'"'"': `Bearer ${this.config.bearer_token}`,\n        '"'"'Content-Type'"'"': '"'"'application\/json'"'"',\n        '"'"'Accept'"'"': '"'"'application\/json, text\/plain, *\/*'"'"'\n      }\n    };\n\n    if (this.proxy) {\n      let proxyAgent;\n      if (this.proxy.startsWith('"'"'socks5:'"'"')) {\n        proxyAgent = new SocksProxyAgent(this.proxy);\n      } else {\n        proxyAgent = new HttpsProxyAgent(this.proxy);\n      }\n      onboardConfig.httpsAgent = proxyAgent;\n      onboardConfig.httpAgent = proxyAgent;\n    }\n\n    const response = await axios.post(`${this.baseUrl}\/v1\/node\/onboard`, /' index.js
    
    sed -i 's/{ address: this.config.wallet_address },\n        {/{ address: this.config.wallet_address },\n        onboardConfig/' index.js
    
    # 修改main函数以支持代理
    sed -i 's/  const bots = accounts.map((account, index) => new ParasailNodeBot(account, index, screen));/  let proxies = [];\n  try {\n    const proxyConfigPath = path.resolve('"'"'.\/proxy_config.json'"'"');\n    if (fs.existsSync(proxyConfigPath)) {\n      const proxyContent = fs.readFileSync(proxyConfigPath, '"'"'utf8'"'"');\n      proxies = proxyContent.split('"'"'\\n'"'"').filter(line => line.trim() !== '"'"''"'"');\n    }\n  } catch (error) {\n    console.error('"'"'Error loading proxy config:'"'"', error);\n  }\n\n  const bots = accounts.map((account, index) => {\n    const proxy = index < proxies.length ? proxies[index] : null;\n    return new ParasailNodeBot(account, index, screen, proxy);\n  });/' index.js
    
    # 安装代理所需的依赖
    npm install https-proxy-agent socks-proxy-agent
    
    cd ..
    
    print_info "代理功能配置完成"
}

# 添加账户和代理信息（一次输入一个）
add_accounts_and_proxies() {
    print_info "正在设置账户和代理信息..."
    
    cd Parasail-Bot
    
    # 初始化数组
    declare -a PRIVATE_KEY_ARRAY
    declare -a PROXY_ARRAY
    
    # 提示用户输入账户和代理
    echo "请逐个输入以太坊私钥，每个私钥一行，输入完成后输入空行结束"
    echo "格式示例: xxxxxxx... (无需添加0x前缀，无需引号)"
    echo "-----------------------------------"
    
    # 确保config.json文件不存在或是空文件，准备写入
    echo "" > config.json
    i=0
    
    while true; do
        read -p "请输入第$((i+1))个私钥 (输入空行结束): " PRIVATE_KEY
        
        if [ -z "$PRIVATE_KEY" ]; then
            if [ $i -eq 0 ]; then
                print_warn "至少需要输入一个私钥"
                continue
            fi
            break
        fi
        
        # 处理私钥格式（如果没有0x前缀，添加它）
        if [[ ! "$PRIVATE_KEY" == 0x* ]]; then
            PRIVATE_KEY="0x$PRIVATE_KEY"
        fi
        
        PRIVATE_KEY_ARRAY+=("$PRIVATE_KEY")
        
        # 询问对应的代理
        read -p "请输入第$((i+1))个代理地址 (HTTP格式: http://user:pass@host:port 或 SOCKS5格式: socks5://user:pass@host:port，直接回车表示不使用代理): " PROXY
        
        if [ -z "$PROXY" ]; then
            PROXY="none"
            print_info "账户 $((i+1)) 不使用代理"
        fi
        
        PROXY_ARRAY+=("$PROXY")
        ((i++))
    done
    
    # 如果没有输入任何账户，提示错误并退出
    if [ ${#PRIVATE_KEY_ARRAY[@]} -eq 0 ]; then
        print_error "未输入任何账户，设置中止"
        cd ..
        return 1
    fi
    
    # 创建新的config.json文件（符合程序要求的格式）
    echo '{' > config.json
    echo '  "accounts": [' >> config.json
    
    for i in "${!PRIVATE_KEY_ARRAY[@]}"; do
        PRIVATE_KEY=${PRIVATE_KEY_ARRAY[$i]}
        echo "    { \"privateKey\": \"$PRIVATE_KEY\" }" >> config.json
        if [ $i -lt $((${#PRIVATE_KEY_ARRAY[@]} - 1)) ]; then
            echo "    ," >> config.json
        fi
    done
    
    echo '  ]' >> config.json
    echo '}' >> config.json
    
    # 更新proxy_config.json（新格式：每行一个代理，没有引号和逗号）
    > proxy_config.json
    
    for i in "${!PROXY_ARRAY[@]}"; do
        PROXY=${PROXY_ARRAY[$i]}
        if [ "$PROXY" != "none" ]; then
            echo "$PROXY" >> proxy_config.json
        else
            # 为没有代理的账户添加空行，保持与账户的对应关系
            echo "" >> proxy_config.json
        fi
    done
    
    print_info "已配置 ${#PRIVATE_KEY_ARRAY[@]} 个账户和代理"
    print_info "配置信息已保存到:"
    print_info "  - $(pwd)/config.json"
    print_info "  - $(pwd)/proxy_config.json"
    
    cd ..
    
    print_info "账户和代理信息设置完成"
}

# 创建服务来后台运行机器人
create_service() {
    print_info "正在创建系统服务来后台运行机器人..."
    
    cat > /etc/systemd/system/parasail-bot.service << EOL
[Unit]
Description=Parasail Auto Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$(pwd)/Parasail-Bot
ExecStart=/usr/bin/node index.js
Restart=on-failure
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=parasail-bot

[Install]
WantedBy=multi-user.target
EOL

    systemctl daemon-reload
    systemctl enable parasail-bot
    
    print_info "系统服务创建完成"
}

# 启动机器人
start_bot() {
    print_info "正在启动Parasail机器人..."
    
    if [ ! -f "/etc/systemd/system/parasail-bot.service" ]; then
        print_error "未检测到系统服务，请先完成安装"
        return 1
    fi
    
    systemctl start parasail-bot
    sleep 2
    
    if systemctl is-active --quiet parasail-bot; then
        print_info "机器人已成功启动"
        print_info "查看日志请使用: journalctl -u parasail-bot -f"
    else
        print_error "机器人启动失败，请检查日志"
        print_info "查看日志请使用: journalctl -u parasail-bot -f"
        return 1
    fi
}

# 停止机器人
stop_bot() {
    print_info "正在停止Parasail机器人..."
    
    if [ ! -f "/etc/systemd/system/parasail-bot.service" ]; then
        print_error "未检测到系统服务，可能机器人未安装"
        return 1
    fi
    
    if ! systemctl is-active --quiet parasail-bot; then
        print_warn "机器人服务当前未运行"
        return 0
    fi
    
    systemctl stop parasail-bot
    sleep 2
    
    if ! systemctl is-active --quiet parasail-bot; then
        print_info "机器人已成功停止"
    else
        print_error "机器人停止失败，请尝试强制终止"
        print_info "强制终止命令: pkill -f 'node index.js'"
        return 1
    fi
}

# 查看机器人状态
status_bot() {
    if [ ! -f "/etc/systemd/system/parasail-bot.service" ]; then
        print_error "未检测到系统服务，可能机器人未安装"
        return 1
    fi
    
    systemctl status parasail-bot
}

# 卸载机器人
uninstall_bot() {
    print_info "正在卸载Parasail机器人..."
    
    stop_bot
    
    systemctl disable parasail-bot
    rm -f /etc/systemd/system/parasail-bot.service
    systemctl daemon-reload
    
    read -p "是否删除Parasail-Bot目录及所有配置? (y/n): " confirm
    if [ "$confirm" = "y" ]; then
        rm -rf Parasail-Bot
        print_info "机器人已完全卸载"
    else
        print_info "机器人服务已卸载，但保留了程序文件和配置"
    fi
}

# 主函数
main() {
    clear
    echo "============================================"
    echo "    Parasail多账号代理机器人管理脚本    "
    echo "============================================"
    echo
    
    echo "请选择操作:"
    echo "1. 安装并配置机器人"
    echo "2. 添加/更新账户和代理"
    echo "3. 启动机器人"
    echo "4. 停止机器人"
    echo "5. 查看机器人状态"
    echo "6. 查看机器人日志"
    echo "7. 卸载机器人"
    echo "0. 退出"
    
    read -p "请输入选项 [0-7]: " option
    
    case $option in
        1)
            check_root
            install_jq
            install_dependencies
            clone_repository
            configure_proxy
            add_accounts_and_proxies
            create_service
            start_bot
            ;;
        2)
            check_root
            if [ ! -d "Parasail-Bot" ]; then
                print_error "未检测到机器人安装，请先安装"
                exit 1
            fi
            install_jq
            add_accounts_and_proxies
            if systemctl is-active --quiet parasail-bot; then
                systemctl restart parasail-bot
                print_info "账户和代理更新完成，服务已重启"
            else
                print_info "账户和代理更新完成，服务未启动"
            fi
            ;;
        3)
            check_root
            if [ ! -d "Parasail-Bot" ]; then
                print_error "未检测到机器人安装，请先安装"
                exit 1
            fi
            start_bot
            ;;
        4)
            check_root
            stop_bot
            ;;
        5)
            status_bot
            ;;
        6)
            if [ ! -f "/etc/systemd/system/parasail-bot.service" ]; then
                print_error "未检测到系统服务，可能机器人未安装"
                exit 1
            fi
            journalctl -u parasail-bot -f
            ;;
        7)
            check_root
            uninstall_bot
            ;;
        0)
            exit 0
            ;;
        *)
            print_error "无效的选项"
            ;;
    esac
}

# 执行主函数
main 