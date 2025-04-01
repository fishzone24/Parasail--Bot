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
    else
        # 如果存在备份，恢复原始文件再修改
        cp index.js.original index.js
    fi
    
    # 创建代理配置文件 (新格式，不包含accounts数组)
    cat > proxy_config.json << EOL
EOL
    
    # 安装代理所需的依赖
    print_info "安装代理所需依赖..."
    npm install https-proxy-agent socks-proxy-agent --save
    
    # 使用更可靠的方式修改index.js
    print_info "修改代码添加代理支持..."
    
    # 1. 添加代理相关的导入
    sed -i '1s/^/\/* Parasail Bot with Proxy Support *\/\n/' index.js
    sed -i '/const axios = require/a const { HttpsProxyAgent } = require('"'"'https-proxy-agent'"'"');\nconst { SocksProxyAgent } = require('"'"'socks-proxy-agent'"'"');' index.js
    
    # 2. 修改构造函数添加代理支持
    sed -i 's/constructor(account, index, screen) {/constructor(account, index, screen, proxy = null) {\n    this.proxy = proxy;/' index.js
    
    # 3. 创建自定义函数来处理代理配置
    cat >> index.js << 'EOL'

// 添加获取代理配置的辅助函数
function getProxyConfig(proxy, headers = {}) {
  const config = { headers };
  
  if (proxy) {
    let proxyAgent;
    if (proxy.startsWith('socks5:')) {
      proxyAgent = new SocksProxyAgent(proxy);
    } else {
      proxyAgent = new HttpsProxyAgent(proxy);
    }
    config.httpsAgent = proxyAgent;
    config.httpAgent = proxyAgent;
  }
  
  return config;
}
EOL

    # 4. 修改axios请求使用代理 - 通用方法
    # 修改所有的axios方法调用来使用代理配置
    
    # verifyUser方法
    sed -i '/const signatureData = await this.generateSignature();/a \ \ \ \ const proxyConfig = this.proxy ? getProxyConfig(this.proxy, {\n      '"'"'Accept'"'"': '"'"'application\/json, text\/plain, *\/*'"'"',\n      '"'"'Content-Type'"'"': '"'"'application\/json'"'"'\n    }) : {\n      headers: {\n        '"'"'Accept'"'"': '"'"'application\/json, text\/plain, *\/*'"'"',\n        '"'"'Content-Type'"'"': '"'"'application\/json'"'"'\n      }\n    };\n\n    if (this.proxy) {\n      this.log(`Using proxy: ${this.proxy}`);\n    }' index.js
    sed -i 's/const response = await axios.post(`${this.baseUrl}\/user\/verify`, signatureData, {/const response = await axios.post(`${this.baseUrl}\/user\/verify`, signatureData, proxyConfig);/g' index.js
    # 删除原来的headers部分
    sed -i '/headers: {/,/},/d' index.js
    
    # getNodeStats方法
    sed -i '/const response = await axios.get(`${this.baseUrl}\/v1\/node\/node_stats`, {/i \ \ \ \ const proxyConfig = this.proxy ? getProxyConfig(this.proxy, {\n      '"'"'Authorization'"'"': `Bearer ${this.config.bearer_token}`,\n      '"'"'Accept'"'"': '"'"'application\/json, text\/plain, *\/*'"'"'\n    }) : {\n      headers: {\n        '"'"'Authorization'"'"': `Bearer ${this.config.bearer_token}`,\n        '"'"'Accept'"'"': '"'"'application\/json, text\/plain, *\/*'"'"'\n      }\n    };\n\n    proxyConfig.params = { address: this.config.wallet_address };' index.js
    sed -i 's/const response = await axios.get(`${this.baseUrl}\/v1\/node\/node_stats`, {/const response = await axios.get(`${this.baseUrl}\/v1\/node\/node_stats`, proxyConfig);/g' index.js
    # 删除原来的headers和params部分
    sed -i '/params: { address: this.config.wallet_address },/,/},/d' index.js
    
    # checkIn方法
    sed -i '/const checkInResponse = await axios.post(/i \ \ \ \ const proxyConfig = this.proxy ? getProxyConfig(this.proxy, {\n      '"'"'Authorization'"'"': `Bearer ${this.config.bearer_token}`,\n      '"'"'Content-Type'"'"': '"'"'application\/json'"'"',\n      '"'"'Accept'"'"': '"'"'application\/json, text\/plain, *\/*'"'"'\n    }) : {\n      headers: {\n        '"'"'Authorization'"'"': `Bearer ${this.config.bearer_token}`,\n        '"'"'Content-Type'"'"': '"'"'application\/json'"'"',\n        '"'"'Accept'"'"': '"'"'application\/json, text\/plain, *\/*'"'"'\n      }\n    };' index.js
    sed -i 's/const checkInResponse = await axios.post(/const checkInResponse = await axios.post(/g' index.js
    sed -i 's/`${this.baseUrl}\/v1\/node\/check_in`, \n        { address: this.config.wallet_address },\n        {/`${this.baseUrl}\/v1\/node\/check_in`, { address: this.config.wallet_address }, proxyConfig);/g' index.js
    # 删除原来的headers部分
    sed -i '/headers: {/,/},/d' index.js
    
    # onboardNode方法
    sed -i '/const response = await axios.post(`${this.baseUrl}\/v1\/node\/onboard`/i \ \ \ \ const proxyConfig = this.proxy ? getProxyConfig(this.proxy, {\n      '"'"'Authorization'"'"': `Bearer ${this.config.bearer_token}`,\n      '"'"'Content-Type'"'"': '"'"'application\/json'"'"',\n      '"'"'Accept'"'"': '"'"'application\/json, text\/plain, *\/*'"'"'\n    }) : {\n      headers: {\n        '"'"'Authorization'"'"': `Bearer ${this.config.bearer_token}`,\n        '"'"'Content-Type'"'"': '"'"'application\/json'"'"',\n        '"'"'Accept'"'"': '"'"'application\/json, text\/plain, *\/*'"'"'\n      }\n    };' index.js
    sed -i 's/const response = await axios.post(`${this.baseUrl}\/v1\/node\/onboard`, /const response = await axios.post(`${this.baseUrl}\/v1\/node\/onboard`, /g' index.js
    sed -i 's/{ address: this.config.wallet_address },\n        {/{ address: this.config.wallet_address }, proxyConfig);/g' index.js
    # 删除原来的headers部分
    sed -i '/headers: {/,/},/d' index.js
    
    # 5. 修改main函数以支持简单格式的config.json和proxy_config.json
    # 找到main函数
    sed -i '/async function main() {/,/main().catch/c\async function main() {\n  // 加载私钥配置（每行一个私钥）\n  let privateKeys = [];\n  try {\n    const configPath = path.resolve('"'"'./config.json'"'"');\n    if (fs.existsSync(configPath)) {\n      const configContent = fs.readFileSync(configPath, '"'"'utf8'"'"');\n      privateKeys = configContent.split('"'"'\\n'"'"').filter(line => line.trim() !== '"'"''"'"');\n      console.log(`Loaded ${privateKeys.length} accounts.`);\n    } else {\n      console.error('"'"'config.json file not found'"'"');\n      process.exit(1);\n    }\n  } catch (error) {\n    console.error('"'"'Error loading accounts config:'"'"', error);\n    process.exit(1);\n  }\n\n  if (privateKeys.length === 0) {\n    console.error('"'"'No accounts found in config.json'"'"');\n    process.exit(1);\n  }\n\n  // 转换为accounts格式\n  const accounts = privateKeys.map(privateKey => ({ privateKey }));\n\n  // 加载代理配置（每行一个代理）\n  let proxies = [];\n  try {\n    const proxyConfigPath = path.resolve('"'"'./proxy_config.json'"'"');\n    if (fs.existsSync(proxyConfigPath)) {\n      const proxyContent = fs.readFileSync(proxyConfigPath, '"'"'utf8'"'"');\n      proxies = proxyContent.split('"'"'\\n'"'"').filter((line, i) => i < privateKeys.length);\n      // 填充空代理以匹配账户数量\n      while (proxies.length < privateKeys.length) {\n        proxies.push('"'"''"'"');\n      }\n      console.log(`Loaded ${proxies.filter(p => p.trim() !== '"'"''"'"').length} proxies.`);\n    }\n  } catch (error) {\n    console.error('"'"'Error loading proxy config:'"'"', error);\n  }\n\n  // 创建一个共享的 blessed 屏幕\n  const screen = blessed.screen({\n    smartCSR: true,\n    title: '"'"'Multi-Account Parasail Bot'"'"'\n  });\n\n  // 记录账户数量，以便动态分配 UI 空间\n  screen.accountsCount = accounts.length;\n\n  // 为每个账户创建 ParasailNodeBot 实例\n  const bots = accounts.map((account, index) => {\n    const proxy = index < proxies.length ? proxies[index].trim() : null;\n    return new ParasailNodeBot(account, index, screen, proxy ? proxy : null);\n  });\n\n  // 添加退出键\n  screen.key(['"'"'q'"'"', '"'"'C-c'"'"'], () => {\n    return process.exit(0);\n  });\n\n  // 底部添加退出提示\n  const quitBox = blessed.box({\n    parent: screen,\n    bottom: 0,\n    left: 0,\n    width: '"'"'100%'"'"',\n    height: 1,\n    content: '"'"'Press Q to Quit'"'"',\n    style: {\n      fg: '"'"'white'"'"',\n      bg: '"'"'gray'"'"'\n    }\n  });\n\n  // 并发启动所有账户\n  await Promise.all(bots.map(bot => bot.start()));\n}\n\nmain().catch(error => {\n  console.error('"'"'Main error:'"'"', error);\n  process.exit(1);\n});' index.js
    
    print_info "代码修改完成，确保配置更可靠"
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
    > config.json
    > proxy_config.json
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
    
    # 创建新的config.json文件（每行一个私钥的简单格式）
    for i in "${!PRIVATE_KEY_ARRAY[@]}"; do
        PRIVATE_KEY=${PRIVATE_KEY_ARRAY[$i]}
        echo "$PRIVATE_KEY" >> config.json
    done
    
    # 更新proxy_config.json（每行一个代理）
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
    
    # 检查依赖是否已安装
    cd Parasail-Bot
    print_info "检查依赖状态..."
    
    if [ ! -d "node_modules/https-proxy-agent" ] || [ ! -d "node_modules/socks-proxy-agent" ]; then
        print_warn "检测到代理依赖未完全安装，正在安装..."
        npm install https-proxy-agent socks-proxy-agent --save
    fi
    
    # 验证配置文件
    if [ ! -f "config.json" ]; then
        print_error "config.json 不存在，请先配置账户"
        cd ..
        return 1
    fi
    
    # 确保配置文件有内容
    if [ ! -s "config.json" ]; then
        print_error "config.json 是空文件，请先配置账户"
        cd ..
        return 1
    fi
    
    cd ..
    
    # 启动服务
    systemctl daemon-reload
    systemctl start parasail-bot
    sleep 3
    
    # 检查启动状态
    if systemctl is-active --quiet parasail-bot; then
        print_info "机器人已成功启动"
        print_info "查看日志请使用: journalctl -u parasail-bot -f"
    else
        print_error "机器人启动失败，正在尝试排查问题..."
        
        # 尝试读取错误日志
        ERROR_LOG=$(journalctl -u parasail-bot -n 20 --no-pager)
        echo "错误日志片段："
        echo "$ERROR_LOG"
        
        # 可能的错误原因和解决方案
        print_warn "可能的问题原因:"
        print_warn "1. 代理配置格式不正确"
        print_warn "2. 文件权限问题"
        print_warn "3. Node.js 版本不兼容"
        print_warn "4. 程序代码修改错误"
        
        print_info "尝试解决方法:"
        print_info "- 选择菜单选项8'修复常见问题'进行自动修复"
        print_info "- 检查 Parasail-Bot/config.json 和 proxy_config.json 格式是否正确"
        print_info "- 运行: cd Parasail-Bot && npm install && npm install https-proxy-agent socks-proxy-agent --save"
        print_info "- 如果使用旧版本Node.js，尝试更新: curl -fsSL https://deb.nodesource.com/setup_16.x | bash - && apt install -y nodejs"
        
        return 1
    fi
}

# 修复常见问题
fix_issues() {
    print_info "开始修复常见问题..."
    
    if [ ! -d "Parasail-Bot" ]; then
        print_error "未检测到Parasail-Bot目录，请先安装"
        return 1
    fi
    
    cd Parasail-Bot
    
    # 1. 检查Node.js版本
    print_info "检查Node.js版本..."
    NODE_VERSION=$(node -v | cut -d 'v' -f 2 | cut -d '.' -f 1)
    if [ "$NODE_VERSION" -lt 14 ]; then
        print_warn "Node.js版本低于14，正在更新..."
        curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
        apt install -y nodejs
        print_info "Node.js已更新，当前版本："
        node -v
    else
        print_info "Node.js版本正常: $(node -v)"
    fi
    
    # 2. 恢复和修复配置文件
    print_info "检查配置文件..."
    
    # 检查index.js是否存在
    if [ ! -f "index.js" ]; then
        print_error "index.js不存在，尝试从备份恢复"
        if [ -f "index.js.original" ]; then
            cp index.js.original index.js
            print_info "已从备份恢复index.js"
        else
            print_error "无法找到index.js备份文件，请重新安装"
            cd ..
            return 1
        fi
    fi
    
    # 3. 重新安装依赖
    print_info "正在重新安装依赖..."
    rm -rf node_modules package-lock.json
    npm install
    npm install https-proxy-agent socks-proxy-agent --save
    
    # 4. 重新配置代理支持
    print_info "重新配置代理支持..."
    
    # 如果有备份则恢复
    if [ -f "index.js.original" ]; then
        cp index.js.original index.js
        print_info "已恢复原始index.js"
    fi
    
    # 重新配置
    print_info "正在重新应用代理配置..."
    cd ..
    configure_proxy
    
    # 5. 验证配置文件格式
    cd Parasail-Bot
    if [ -f "config.json" ]; then
        if [ ! -s "config.json" ]; then
            print_warn "config.json为空，请重新设置账户"
            cd ..
            add_accounts_and_proxies
        else
            print_info "config.json格式正确"
            
            # 检查文件内容，每行应该是一个私钥
            local key_count=$(wc -l < config.json)
            print_info "检测到 $key_count 个私钥"
        fi
    else
        print_warn "找不到config.json，请设置账户"
        cd ..
        add_accounts_and_proxies
    fi
    
    # 6. 检查代理配置
    if [ -f "proxy_config.json" ]; then
        local proxy_count=$(grep -v "^$" proxy_config.json | wc -l)
        print_info "检测到 $proxy_count 个代理配置"
    else
        print_warn "未找到proxy_config.json，创建空文件"
        touch proxy_config.json
    fi
    
    # 7. 修复文件权限
    print_info "修复文件权限..."
    chmod -R 755 .
    
    cd ..
    
    # 8. 重启服务
    print_info "正在重新加载系统服务..."
    systemctl daemon-reload
    
    if systemctl is-active --quiet parasail-bot; then
        print_info "重启parasail-bot服务..."
        systemctl restart parasail-bot
    else
        print_info "启动parasail-bot服务..."
        systemctl start parasail-bot
    fi
    
    sleep 3
    
    if systemctl is-active --quiet parasail-bot; then
        print_info "服务已成功启动!"
    else
        print_error "服务启动失败，查看错误日志:"
        journalctl -u parasail-bot -n 10 --no-pager
        
        print_info "尝试进一步修复..."
        print_info "1. 完全重置代码和配置..."
        
        # 备份当前配置
        if [ -f "Parasail-Bot/config.json" ]; then
            cp Parasail-Bot/config.json Parasail-Bot/config.json.bak
        fi
        
        if [ -f "Parasail-Bot/proxy_config.json" ]; then
            cp Parasail-Bot/proxy_config.json Parasail-Bot/proxy_config.json.bak
        fi
        
        # 删除目录并重新安装
        cd Parasail-Bot
        rm -rf node_modules package-lock.json
        cd ..
        clone_repository
        configure_proxy
        
        # 恢复配置
        if [ -f "Parasail-Bot/config.json.bak" ]; then
            cp Parasail-Bot/config.json.bak Parasail-Bot/config.json
            print_info "已恢复账户配置"
        fi
        
        if [ -f "Parasail-Bot/proxy_config.json.bak" ]; then
            cp Parasail-Bot/proxy_config.json.bak Parasail-Bot/proxy_config.json
            print_info "已恢复代理配置"
        fi
        
        print_info "重启服务..."
        systemctl daemon-reload
        systemctl restart parasail-bot
        
        sleep 3
        
        if systemctl is-active --quiet parasail-bot; then
            print_info "服务已成功启动!"
        else
            print_error "服务启动仍然失败，请尝试重新安装或手动检查配置"
            journalctl -u parasail-bot -n 10 --no-pager
        fi
    fi
    
    print_info "修复流程完成"
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
    echo -e "${BLUE}==================================================================${RESET}"
    echo -e "${GREEN}Parasail-Bot一键管理脚本${RESET}"
    echo -e "${YELLOW}脚本作者: fishzone24 - 推特: https://x.com/fishzone24${RESET}"
    echo -e "${YELLOW}此脚本为免费开源脚本，如有问题请提交 issue${RESET}"
    echo -e "${BLUE}==================================================================${RESET}"
    echo
    
    echo "请选择操作:"
    echo "1. 安装并配置机器人"
    echo "2. 添加/更新账户和代理"
    echo "3. 启动机器人"
    echo "4. 停止机器人"
    echo "5. 查看机器人状态"
    echo "6. 查看机器人日志"
    echo "7. 卸载机器人"
    echo "8. 修复常见问题"
    echo "0. 退出"
    
    read -p "请输入选项 [0-8]: " option
    
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
        8)
            check_root
            fix_issues
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