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

# 预安装检查和自动修复常见问题
preinstall_checks() {
    print_info "执行预安装检查和自动修复..."
    
    # 1. 检查操作系统和软件包管理器
    if command -v apt &> /dev/null; then
        print_info "检测到Debian/Ubuntu系统，继续安装..."
        
        # 更新软件包列表
        apt update -y
        
        # 1.1 检查curl是否安装
        if ! command -v curl &> /dev/null; then
            print_warn "curl未安装，正在安装..."
            apt install -y curl
        fi
        
        # 1.2 检查git是否安装
        if ! command -v git &> /dev/null; then
            print_warn "git未安装，正在安装..."
            apt install -y git
        fi
        
        # 1.3 检查Node.js
        if ! command -v node &> /dev/null; then
            print_warn "Node.js未安装，正在安装..."
            curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
            apt install -y nodejs
        else
            NODE_VERSION=$(node -v | cut -d 'v' -f 2 | cut -d '.' -f 1)
            if [ "$NODE_VERSION" -lt 14 ] || [ "$NODE_VERSION" -gt 18 ]; then
                print_warn "Node.js版本不兼容（${NODE_VERSION}），建议使用v14-v16版本，正在安装v16..."
                curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
                apt install -y nodejs
            fi
        fi
        
        # 1.4 检查npm
        if ! command -v npm &> /dev/null; then
            print_warn "npm未安装，正在安装..."
            apt install -y npm
        fi
    else
        print_warn "未检测到apt包管理器，可能不是Debian/Ubuntu系统，将尝试继续但可能会有兼容性问题..."
    fi
    
    # 2. 创建必要目录
    if [ ! -d "Parasail-Bot" ]; then
        print_info "创建Parasail-Bot目录..."
        mkdir -p Parasail-Bot
    fi
    
    # 3. 预先安装代理相关依赖包
    if [ -d "Parasail-Bot" ]; then
        cd Parasail-Bot
        
        # 创建package.json（如果不存在）
        if [ ! -f "package.json" ]; then
            print_info "创建package.json..."
            cat > package.json << EOL
{
  "name": "parasail-bot",
  "version": "1.0.0",
  "description": "Parasail Node Bot",
  "main": "index.js",
  "dependencies": {
    "axios": "^0.27.2",
    "blessed": "^0.1.81",
    "ethers": "^5.6.8",
    "https-proxy-agent": "^5.0.1",
    "socks-proxy-agent": "^7.0.0"
  },
  "scripts": {
    "start": "node index.js"
  }
}
EOL
        fi
        
        # 安装代理所需依赖
        print_info "预安装代理所需依赖..."
        npm install https-proxy-agent socks-proxy-agent --save
        
        cd ..
    fi
    
    # 4. 检查系统服务配置
    if [ -f "/etc/systemd/system/parasail-bot.service" ]; then
        # 检查是否包含过时的syslog配置
        if grep -q "StandardOutput=syslog" "/etc/systemd/system/parasail-bot.service"; then
            print_warn "检测到系统服务使用过时的syslog配置，正在更新..."
            # 更新服务文件
            sed -i 's/StandardOutput=syslog//' "/etc/systemd/system/parasail-bot.service"
            sed -i 's/StandardError=syslog//' "/etc/systemd/system/parasail-bot.service"
            systemctl daemon-reload
        fi
    fi
    
    print_info "预安装检查和自动修复完成"
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
        # 修改Node.js版本检查逻辑：如果版本过高也进行降级
        if [ "$NODE_VERSION" -lt 14 ] || [ "$NODE_VERSION" -gt 18 ]; then
            print_warn "Node.js版本不兼容（${NODE_VERSION}），建议使用v14-v16版本，正在安装v16..."
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
        print_info "备份原始index.js文件..."
        cp index.js index.js.original
    fi
    
    # 创建代理配置文件 (新格式，不包含accounts数组)
    touch proxy_config.json
    
    # 安装代理所需的依赖
    print_info "安装代理所需依赖..."
    npm install https-proxy-agent socks-proxy-agent --save

    # 使用完整预构建的index.js文件替换现有文件
    print_info "替换index.js文件，添加代理支持..."
    
    # 创建支持代理的index.js文件
    cat > index.js << 'EOL'
/* Parasail Bot with Proxy Support */
const axios = require('axios');
const { ethers } = require('ethers');
const fs = require('fs');
const path = require('path');
const blessed = require('blessed');
const { HttpsProxyAgent } = require('https-proxy-agent');
const { SocksProxyAgent } = require('socks-proxy-agent');

// 获取代理配置的辅助函数
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

class ParasailNodeBot {
  constructor(account, index, screen, proxy = null) {
    this.account = account;
    this.index = index;
    this.screen = screen;
    this.proxy = proxy;
    this.baseUrl = 'https://api.slicksurfer.xyz';
    this.config = {};
    this.nodeInfo = {};
    
    // UI 创建
    const height = Math.floor((screen.height - 3) / screen.accountsCount);
    this.log_box = blessed.log({
      parent: screen,
      top: index * height,
      left: 0,
      width: '100%',
      height: height,
      border: {
        type: 'line'
      },
      style: {
        fg: 'green',
        border: {
          fg: 'blue'
        }
      },
      scrollable: true,
      scrollbar: {
        style: {
          bg: 'white'
        }
      }
    });
  }
  
  log(message) {
    const time = new Date().toLocaleTimeString();
    this.log_box.log(`[${time}] [Account ${this.index + 1}] ${message}`);
    this.screen.render();
  }
  
  async generateSignature() {
    // 创建钱包
    const wallet = new ethers.Wallet(this.account.privateKey);
    
    // 获取钱包地址
    const address = await wallet.getAddress();
    this.config.wallet_address = address;
    
    // 签名消息
    const message = 'You are starting the PARASAIL NODE for Brawler Bearz Labs.';
    const signature = await wallet.signMessage(message);
    
    return {
      message,
      signature,
      address
    };
  }
  
  async verifyUser() {
    this.log('正在验证钱包...');
    
    try {
      const signatureData = await this.generateSignature();
      
      const proxyConfig = this.proxy ? getProxyConfig(this.proxy, {
        'Accept': 'application/json, text/plain, */*',
        'Content-Type': 'application/json'
      }) : {
        headers: {
          'Accept': 'application/json, text/plain, */*',
          'Content-Type': 'application/json'
        }
      };
      
      if (this.proxy) {
        this.log(`使用代理: ${this.proxy}`);
      }
      
      const response = await axios.post(`${this.baseUrl}/user/verify`, signatureData, proxyConfig);
      
      if (response.data && response.data.bearer_token) {
        this.config.bearer_token = response.data.bearer_token;
        this.log('钱包验证成功');
        return true;
      } else {
        this.log('钱包验证失败: 响应中没有token');
        return false;
      }
    } catch (error) {
      this.log(`钱包验证错误: ${error.message}`);
      if (error.response) {
        this.log(`状态码: ${error.response.status}`);
      }
      return false;
    }
  }
  
  async getNodeStats() {
    this.log('查询节点状态...');
    
    try {
      const proxyConfig = this.proxy ? getProxyConfig(this.proxy, {
        'Authorization': `Bearer ${this.config.bearer_token}`,
        'Accept': 'application/json, text/plain, */*'
      }) : {
        headers: {
          'Authorization': `Bearer ${this.config.bearer_token}`,
          'Accept': 'application/json, text/plain, */*'
        }
      };
      
      proxyConfig.params = { address: this.config.wallet_address };
      
      const response = await axios.get(`${this.baseUrl}/v1/node/node_stats`, proxyConfig);
      
      if (response.data) {
        this.nodeInfo = response.data;
        this.log(`节点状态: ${response.data.status || 'unknown'}`);
        return response.data;
      }
      return null;
    } catch (error) {
      this.log(`获取节点状态错误: ${error.message}`);
      return null;
    }
  }
  
  async checkIn() {
    this.log('执行节点签到...');
    
    try {
      const proxyConfig = this.proxy ? getProxyConfig(this.proxy, {
        'Authorization': `Bearer ${this.config.bearer_token}`,
        'Content-Type': 'application/json',
        'Accept': 'application/json, text/plain, */*'
      }) : {
        headers: {
          'Authorization': `Bearer ${this.config.bearer_token}`,
          'Content-Type': 'application/json',
          'Accept': 'application/json, text/plain, */*'
        }
      };
      
      const checkInResponse = await axios.post(`${this.baseUrl}/v1/node/check_in`, { address: this.config.wallet_address }, proxyConfig);
      
      if (checkInResponse.data) {
        this.log(`签到成功: ${JSON.stringify(checkInResponse.data)}`);
        return true;
      }
      return false;
    } catch (error) {
      this.log(`签到错误: ${error.message}`);
      return false;
    }
  }

  async onboardNode() {
    this.log('正在注册新节点...');
    
    try {
      const proxyConfig = this.proxy ? getProxyConfig(this.proxy, {
        'Authorization': `Bearer ${this.config.bearer_token}`,
        'Content-Type': 'application/json',
        'Accept': 'application/json, text/plain, */*'
      }) : {
        headers: {
          'Authorization': `Bearer ${this.config.bearer_token}`,
          'Content-Type': 'application/json',
          'Accept': 'application/json, text/plain, */*'
        }
      };
      
      const response = await axios.post(`${this.baseUrl}/v1/node/onboard`, { address: this.config.wallet_address }, proxyConfig);
      
      if (response.data) {
        this.log(`节点注册成功: ${JSON.stringify(response.data)}`);
        return true;
      }
      return false;
    } catch (error) {
      this.log(`节点注册错误: ${error.message}`);
      if (error.response && error.response.data) {
        this.log(`响应详情: ${JSON.stringify(error.response.data)}`);
      }
      return false;
    }
  }
  
  async start() {
    this.log('初始化账户...');
    
    try {
      // 验证用户
      const userVerified = await this.verifyUser();
      
      if (!userVerified) {
        this.log('用户验证失败，无法继续');
        return;
      }
      
      // 获取节点状态
      const stats = await this.getNodeStats();
      
      if (stats && stats.status === 'active') {
        this.log('节点已激活');
        
        // 开始定期签到
        await this.checkIn();
        
        // 10分钟签到一次
        setInterval(async () => {
          await this.checkIn();
        }, 10 * 60 * 1000);
        
      } else {
        this.log('节点未激活，尝试注册');
        const registered = await this.onboardNode();
        
        if (registered) {
          this.log('节点已成功注册，等待激活');
          
          // 等待节点状态变为active
          const checkStatus = async () => {
            const stats = await this.getNodeStats();
            
            if (stats && stats.status === 'active') {
              this.log('节点已激活，开始执行定期签到');
              
              // 执行首次签到
              await this.checkIn();
              
              // 10分钟签到一次
              setInterval(async () => {
                await this.checkIn();
              }, 10 * 60 * 1000);
              
              return;
            }
            
            // 继续等待
            this.log('等待节点激活...');
            setTimeout(checkStatus, 30 * 1000);
          };
          
          // 开始检查状态
          setTimeout(checkStatus, 30 * 1000);
        } else {
          this.log('节点注册失败');
        }
      }
    } catch (error) {
      this.log(`启动过程中出错: ${error.message}`);
    }
  }
}

async function main() {
  // 加载私钥配置（每行一个私钥）
  let privateKeys = [];
  try {
    const configPath = path.resolve('./config.json');
    if (fs.existsSync(configPath)) {
      const configContent = fs.readFileSync(configPath, 'utf8');
      privateKeys = configContent.split('\n').filter(line => line.trim() !== '');
      console.log(`已加载 ${privateKeys.length} 个账户`);
    } else {
      console.error('config.json 文件不存在');
      process.exit(1);
    }
  } catch (error) {
    console.error('加载账户配置错误:', error);
    process.exit(1);
  }

  if (privateKeys.length === 0) {
    console.error('config.json 中没有找到任何账户');
    process.exit(1);
  }

  // 转换为accounts格式
  const accounts = privateKeys.map(privateKey => ({ privateKey }));

  // 加载代理配置（每行一个代理）
  let proxies = [];
  try {
    const proxyConfigPath = path.resolve('./proxy_config.json');
    if (fs.existsSync(proxyConfigPath)) {
      const proxyContent = fs.readFileSync(proxyConfigPath, 'utf8');
      proxies = proxyContent.split('\n').filter(line => line.trim() !== '');
      console.log(`已加载 ${proxies.length} 个代理`);
    }
  } catch (error) {
    console.error('加载代理配置错误:', error);
  }

  // 创建一个共享的 blessed 屏幕
  const screen = blessed.screen({
    smartCSR: true,
    title: 'Multi-Account Parasail Bot'
  });

  // 记录账户数量，以便动态分配 UI 空间
  screen.accountsCount = accounts.length;

  // 为每个账户创建 ParasailNodeBot 实例
  const bots = accounts.map((account, index) => {
    const proxy = index < proxies.length ? proxies[index] : null;
    return new ParasailNodeBot(account, index, screen, proxy && proxy.trim() !== '' ? proxy : null);
  });

  // 添加退出键
  screen.key(['q', 'C-c'], () => {
    return process.exit(0);
  });

  // 底部添加退出提示
  const quitBox = blessed.box({
    parent: screen,
    bottom: 0,
    left: 0,
    width: '100%',
    height: 1,
    content: '按 Q 退出',
    style: {
      fg: 'white',
      bg: 'gray'
    }
  });

  // 并发启动所有账户
  await Promise.all(bots.map(bot => bot.start()));
}

main().catch(error => {
  console.error('主程序错误:', error);
  process.exit(1);
});
EOL

    # 测试语法
    if ! node --check index.js &>/dev/null; then
        print_error "生成的index.js文件存在语法错误，尝试恢复原始文件"
        if [ -f "index.js.original" ]; then
            cp index.js.original index.js
            print_info "已恢复原始index.js文件"
        fi
        return 1
    fi
    
    print_info "代码更新成功，已添加代理支持"
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
    
    # 备份当前index.js（如果没有备份）
    if [ -f "index.js" ] && [ ! -f "index.js.backup_syntax" ]; then
        cp index.js index.js.backup_syntax
        print_info "已创建index.js语法备份"
    fi
    
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
    
    # 检查index.js语法错误
    print_info "检查index.js是否有语法错误..."
    if ! node --check index.js &>/dev/null; then
        print_warn "检测到index.js语法错误，进行完全重置..."
        
        # 从备份恢复或创建新文件
        if [ -f "index.js.original" ]; then
            cp index.js.original index.js
            print_info "已从原始备份恢复index.js"
        else
            print_warn "未找到原始备份，创建新的index.js文件"
            
            # 使用完整预构建的index.js文件替换现有文件
            print_info "替换index.js文件，添加代理支持..."
            
            # 创建支持代理的index.js文件
            cat > index.js << 'EOL'
/* Parasail Bot with Proxy Support */
const axios = require('axios');
const { ethers } = require('ethers');
const fs = require('fs');
const path = require('path');
const blessed = require('blessed');
const { HttpsProxyAgent } = require('https-proxy-agent');
const { SocksProxyAgent } = require('socks-proxy-agent');

// 获取代理配置的辅助函数
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

class ParasailNodeBot {
  constructor(account, index, screen, proxy = null) {
    this.account = account;
    this.index = index;
    this.screen = screen;
    this.proxy = proxy;
    this.baseUrl = 'https://api.slicksurfer.xyz';
    this.config = {};
    this.nodeInfo = {};
    
    // UI 创建
    const height = Math.floor((screen.height - 3) / screen.accountsCount);
    this.log_box = blessed.log({
      parent: screen,
      top: index * height,
      left: 0,
      width: '100%',
      height: height,
      border: {
        type: 'line'
      },
      style: {
        fg: 'green',
        border: {
          fg: 'blue'
        }
      },
      scrollable: true,
      scrollbar: {
        style: {
          bg: 'white'
        }
      }
    });
  }
  
  log(message) {
    const time = new Date().toLocaleTimeString();
    this.log_box.log(`[${time}] [Account ${this.index + 1}] ${message}`);
    this.screen.render();
  }
  
  async generateSignature() {
    // 创建钱包
    const wallet = new ethers.Wallet(this.account.privateKey);
    
    // 获取钱包地址
    const address = await wallet.getAddress();
    this.config.wallet_address = address;
    
    // 签名消息
    const message = 'You are starting the PARASAIL NODE for Brawler Bearz Labs.';
    const signature = await wallet.signMessage(message);
    
    return {
      message,
      signature,
      address
    };
  }
  
  async verifyUser() {
    this.log('正在验证钱包...');
    
    try {
      const signatureData = await this.generateSignature();
      
      const proxyConfig = this.proxy ? getProxyConfig(this.proxy, {
        'Accept': 'application/json, text/plain, */*',
        'Content-Type': 'application/json'
      }) : {
        headers: {
          'Accept': 'application/json, text/plain, */*',
          'Content-Type': 'application/json'
        }
      };
      
      if (this.proxy) {
        this.log(`使用代理: ${this.proxy}`);
      }
      
      const response = await axios.post(`${this.baseUrl}/user/verify`, signatureData, proxyConfig);
      
      if (response.data && response.data.bearer_token) {
        this.config.bearer_token = response.data.bearer_token;
        this.log('钱包验证成功');
        return true;
      } else {
        this.log('钱包验证失败: 响应中没有token');
        return false;
      }
    } catch (error) {
      this.log(`钱包验证错误: ${error.message}`);
      if (error.response) {
        this.log(`状态码: ${error.response.status}`);
      }
      return false;
    }
  }
  
  async getNodeStats() {
    this.log('查询节点状态...');
    
    try {
      const proxyConfig = this.proxy ? getProxyConfig(this.proxy, {
        'Authorization': `Bearer ${this.config.bearer_token}`,
        'Accept': 'application/json, text/plain, */*'
      }) : {
        headers: {
          'Authorization': `Bearer ${this.config.bearer_token}`,
          'Accept': 'application/json, text/plain, */*'
        }
      };
      
      proxyConfig.params = { address: this.config.wallet_address };
      
      const response = await axios.get(`${this.baseUrl}/v1/node/node_stats`, proxyConfig);
      
      if (response.data) {
        this.nodeInfo = response.data;
        this.log(`节点状态: ${response.data.status || 'unknown'}`);
        return response.data;
      }
      return null;
    } catch (error) {
      this.log(`获取节点状态错误: ${error.message}`);
      return null;
    }
  }
  
  async checkIn() {
    this.log('执行节点签到...');
    
    try {
      const proxyConfig = this.proxy ? getProxyConfig(this.proxy, {
        'Authorization': `Bearer ${this.config.bearer_token}`,
        'Content-Type': 'application/json',
        'Accept': 'application/json, text/plain, */*'
      }) : {
        headers: {
          'Authorization': `Bearer ${this.config.bearer_token}`,
          'Content-Type': 'application/json',
          'Accept': 'application/json, text/plain, */*'
        }
      };
      
      const checkInResponse = await axios.post(`${this.baseUrl}/v1/node/check_in`, { address: this.config.wallet_address }, proxyConfig);
      
      if (checkInResponse.data) {
        this.log(`签到成功: ${JSON.stringify(checkInResponse.data)}`);
        return true;
      }
      return false;
    } catch (error) {
      this.log(`签到错误: ${error.message}`);
      return false;
    }
  }

  async onboardNode() {
    this.log('正在注册新节点...');
    
    try {
      const proxyConfig = this.proxy ? getProxyConfig(this.proxy, {
        'Authorization': `Bearer ${this.config.bearer_token}`,
        'Content-Type': 'application/json',
        'Accept': 'application/json, text/plain, */*'
      }) : {
        headers: {
          'Authorization': `Bearer ${this.config.bearer_token}`,
          'Content-Type': 'application/json',
          'Accept': 'application/json, text/plain, */*'
        }
      };
      
      const response = await axios.post(`${this.baseUrl}/v1/node/onboard`, { address: this.config.wallet_address }, proxyConfig);
      
      if (response.data) {
        this.log(`节点注册成功: ${JSON.stringify(response.data)}`);
        return true;
      }
      return false;
    } catch (error) {
      this.log(`节点注册错误: ${error.message}`);
      if (error.response && error.response.data) {
        this.log(`响应详情: ${JSON.stringify(error.response.data)}`);
      }
      return false;
    }
  }
  
  async start() {
    this.log('初始化账户...');
    
    try {
      // 验证用户
      const userVerified = await this.verifyUser();
      
      if (!userVerified) {
        this.log('用户验证失败，无法继续');
        return;
      }
      
      // 获取节点状态
      const stats = await this.getNodeStats();
      
      if (stats && stats.status === 'active') {
        this.log('节点已激活');
        
        // 开始定期签到
        await this.checkIn();
        
        // 10分钟签到一次
        setInterval(async () => {
          await this.checkIn();
        }, 10 * 60 * 1000);
        
      } else {
        this.log('节点未激活，尝试注册');
        const registered = await this.onboardNode();
        
        if (registered) {
          this.log('节点已成功注册，等待激活');
          
          // 等待节点状态变为active
          const checkStatus = async () => {
            const stats = await this.getNodeStats();
            
            if (stats && stats.status === 'active') {
              this.log('节点已激活，开始执行定期签到');
              
              // 执行首次签到
              await this.checkIn();
              
              // 10分钟签到一次
              setInterval(async () => {
                await this.checkIn();
              }, 10 * 60 * 1000);
              
              return;
            }
            
            // 继续等待
            this.log('等待节点激活...');
            setTimeout(checkStatus, 30 * 1000);
          };
          
          // 开始检查状态
          setTimeout(checkStatus, 30 * 1000);
        } else {
          this.log('节点注册失败');
        }
      }
    } catch (error) {
      this.log(`启动过程中出错: ${error.message}`);
    }
  }
}

async function main() {
  // 加载私钥配置（每行一个私钥）
  let privateKeys = [];
  try {
    const configPath = path.resolve('./config.json');
    if (fs.existsSync(configPath)) {
      const configContent = fs.readFileSync(configPath, 'utf8');
      privateKeys = configContent.split('\n').filter(line => line.trim() !== '');
      console.log(`已加载 ${privateKeys.length} 个账户`);
    } else {
      console.error('config.json 文件不存在');
      process.exit(1);
    }
  } catch (error) {
    console.error('加载账户配置错误:', error);
    process.exit(1);
  }

  if (privateKeys.length === 0) {
    console.error('config.json 中没有找到任何账户');
    process.exit(1);
  }

  // 转换为accounts格式
  const accounts = privateKeys.map(privateKey => ({ privateKey }));

  // 加载代理配置（每行一个代理）
  let proxies = [];
  try {
    const proxyConfigPath = path.resolve('./proxy_config.json');
    if (fs.existsSync(proxyConfigPath)) {
      const proxyContent = fs.readFileSync(proxyConfigPath, 'utf8');
      proxies = proxyContent.split('\n').filter(line => line.trim() !== '');
      console.log(`已加载 ${proxies.length} 个代理`);
    }
  } catch (error) {
    console.error('加载代理配置错误:', error);
  }

  // 创建一个共享的 blessed 屏幕
  const screen = blessed.screen({
    smartCSR: true,
    title: 'Multi-Account Parasail Bot'
  });

  // 记录账户数量，以便动态分配 UI 空间
  screen.accountsCount = accounts.length;

  // 为每个账户创建 ParasailNodeBot 实例
  const bots = accounts.map((account, index) => {
    const proxy = index < proxies.length ? proxies[index] : null;
    return new ParasailNodeBot(account, index, screen, proxy && proxy.trim() !== '' ? proxy : null);
  });

  // 添加退出键
  screen.key(['q', 'C-c'], () => {
    return process.exit(0);
  });

  // 底部添加退出提示
  const quitBox = blessed.box({
    parent: screen,
    bottom: 0,
    left: 0,
    width: '100%',
    height: 1,
    content: '按 Q 退出',
    style: {
      fg: 'white',
      bg: 'gray'
    }
  });

  // 并发启动所有账户
  await Promise.all(bots.map(bot => bot.start()));
}

main().catch(error => {
  console.error('主程序错误:', error);
  process.exit(1);
});
EOL
            print_info "创建了新的index.js文件"
        fi
    else
        print_info "index.js语法检查通过"
    fi
    
    # 3. 重新安装依赖
    print_info "正在重新安装依赖..."
    rm -rf node_modules package-lock.json
    npm install
    npm install https-proxy-agent socks-proxy-agent --save
    
    # 4. 修复配置文件
    print_info "修复配置文件..."
    
    # 确保proxy_config.json存在
    if [ ! -f "proxy_config.json" ]; then
        touch proxy_config.json
        print_info "创建了空的proxy_config.json文件"
    fi
    
    # 检查并修复config.json格式
    if [ -f "config.json" ]; then
        if [ ! -s "config.json" ]; then
            print_warn "config.json为空，请重新设置账户"
            cd ..
            add_accounts_and_proxies
        else
            # 规范化config.json格式，确保每行一个私钥
            print_info "规范化config.json格式..."
            # 创建临时文件
            cp config.json config.json.tmp
            # 提取所有私钥
            grep -o '0x[0-9a-fA-F]\{64\}' config.json.tmp > config.json.clean
            # 如果没有0x前缀的，也提取出来
            grep -o '[0-9a-fA-F]\{64\}' config.json.tmp | grep -v '^0x' | sed 's/^/0x/' >> config.json.clean
            # 如果有重复的，去重
            sort config.json.clean | uniq > config.json
            rm config.json.tmp config.json.clean
            
            # 检查文件内容，每行应该是一个私钥
            local key_count=$(grep -v "^$" config.json | wc -l)
            print_info "检测到 $key_count 个私钥"
        fi
    else
        print_warn "找不到config.json，请设置账户"
        cd ..
        add_accounts_and_proxies
    fi
    
    # 验证代理配置文件格式
    if [ -f "proxy_config.json" ]; then
        # 规范化proxy_config.json格式
        print_info "规范化proxy_config.json格式..."
        # 删除空白行、注释和JSON符号
        sed -i '/^$/d; /^#/d; s/\[//g; s/\]//g; s/,//g; s/"//g; s/{//g; s/}//g' proxy_config.json
        # 去除每行开头和结尾的空白
        sed -i 's/^[[:space:]]*//g; s/[[:space:]]*$//g' proxy_config.json
        
        # 统计有效代理
        local proxy_count=$(grep -v "^$" proxy_config.json | wc -l)
        print_info "检测到 $proxy_count 个代理配置"
    fi
    
    # 5. 修复文件权限
    print_info "修复文件权限..."
    chmod -R 755 .
    chmod 644 *.json
    
    cd ..
    
    # 6. 重启服务
    print_info "正在重新加载系统服务..."
    systemctl daemon-reload
    
    if systemctl is-active --quiet parasail-bot; then
        print_info "重启parasail-bot服务..."
        systemctl restart parasail-bot
    else
        print_info "启动parasail-bot服务..."
        systemctl start parasail-bot
    fi
    
    sleep 5
    
    if systemctl is-active --quiet parasail-bot; then
        print_info "服务已成功启动!"
    else
        print_error "服务启动失败，查看错误日志:"
        journalctl -u parasail-bot -n 15 --no-pager
        
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
            
            # 确保proxy_config.json格式正确
            cd Parasail-Bot
            sed -i '/^$/d; /^#/d; s/\[//g; s/\]//g; s/,//g; s/"//g; s/{//g; s/}//g' proxy_config.json
            sed -i 's/^[[:space:]]*//g; s/[[:space:]]*$//g' proxy_config.json
            cd ..
        fi
        
        print_info "重启服务..."
        systemctl daemon-reload
        systemctl restart parasail-bot
        
        sleep 5
        
        if systemctl is-active --quiet parasail-bot; then
            print_info "服务已成功启动!"
        else
            print_error "服务启动仍然失败，请尝试重新安装或手动检查配置"
            journalctl -u parasail-bot -n 15 --no-pager
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
            # 执行预安装检查
            preinstall_checks
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
            # 在启动前执行预安装检查，确保环境正常
            preinstall_checks
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
            # 在修复前执行预安装检查
            preinstall_checks
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