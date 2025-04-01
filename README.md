# Parasail多账号代理机器人

## 项目描述
这是一个用于Parasail网络节点的多账号自动化管理工具，支持代理功能，可以帮助用户管理多个账户并通过不同代理IP进行操作。

## 功能特点
- 支持多个以太坊钱包账户同时运行
- 支持为每个账户配置独立的HTTP/HTTPS或SOCKS5代理
- 自动验证用户、节点上线、定期签到
- 实时节点状态监控
- 以系统服务方式在后台运行
- 通过终端UI显示每个账户的状态和日志

## 系统要求
- Ubuntu 18.04+ / Debian 10+
- Node.js 14+ (脚本会自动安装)
- 稳定的互联网连接

## 一键安装

### 方法一：直接下载并执行
在Ubuntu/Debian系统上使用root权限执行以下命令：

```bash
wget -O parasail-bot.sh https://raw.githubusercontent.com/fishzone24/Parasail-Bot/main/parasail-bot.sh && chmod +x parasail-bot.sh && ./parasail-bot.sh
```

### 方法二：手动下载并安装

1. 下载安装脚本：
```bash
wget -O parasail-bot.sh https://raw.githubusercontent.com/fishzone24/Parasail-Bot/main/parasail-bot.sh
```

2. 添加执行权限：
```bash
chmod +x parasail-bot.sh
```

3. 执行安装脚本：
```bash
./parasail-bot.sh
```

## 使用说明

安装脚本提供了以下功能菜单：

1. **安装并配置机器人** - 完整安装，包括下载代码、配置代理、设置账户和代理信息，并启动机器人
2. **添加/更新账户和代理** - 更新现有安装的账户和代理信息
3. **启动机器人** - 启动机器人服务
4. **停止机器人** - 停止机器人服务
5. **查看机器人状态** - 查看服务状态
6. **查看机器人日志** - 实时查看运行日志
7. **卸载机器人** - 完全移除机器人及其服务
0. **退出** - 退出脚本

### 配置文件说明

安装完成后，会生成两个主要配置文件，位于`Parasail-Bot`目录中：

1. **config.json** - 包含以太坊钱包私钥信息，每行一个私钥，格式如下：
```
0xYourFirstPrivateKey
0xYourSecondPrivateKey
0xYourThirdPrivateKey
```

用户输入格式示例（不需要0x前缀，不需要引号）：
```
xxxxxxxxxxxxxxxxxxxxxxx
yyyyyyyyyyyyyyyyyyyyyyy
zzzzzzzzzzzzzzzzzzzzzzz
```

2. **proxy_config.json** - 包含代理配置信息，每行一个代理地址，对应config.json中的私钥顺序，例如：
```
http://user:pass@192.168.1.1:8080
socks5://user:pass@192.168.1.2:1080

```

不使用代理的账户对应的行留空（空行）。

### 配置代理

本脚本支持两种代理类型：

1. **HTTP/HTTPS代理**：格式为 `http://用户名:密码@主机:端口` 或 `http://主机:端口`
   - 例如：`http://user:pass@192.168.1.1:8080` 或 `http://127.0.0.1:7890`

2. **SOCKS5代理**：格式为 `socks5://用户名:密码@主机:端口` 或 `socks5://主机:端口`
   - 例如：`socks5://user:pass@192.168.1.2:1080` 或 `socks5://127.0.0.1:1080`

添加账户和代理时，脚本会提示您逐个输入账户私钥和对应的代理地址，按照提示操作即可。程序会为每个账户配对对应的代理（如果提供）。

## 安全注意事项
- 脚本需要使用以太坊私钥，请确保在安全的环境中运行
- 为该机器人使用专用的钱包，不要使用您的主要资金钱包
- 代理信息会保存在本地配置文件中，请确保服务器安全

## 疑难解答

### 查看日志
```bash
journalctl -u parasail-bot -f
```

### 重启服务
```bash
systemctl restart parasail-bot
```

### 检查服务状态
```bash
systemctl status parasail-bot
```

### 手动修改配置
如果您需要手动修改配置，可以直接编辑以下文件：
```bash
nano Parasail-Bot/config.json
nano Parasail-Bot/proxy_config.json
```
修改完成后需要重启服务：
```bash
systemctl restart parasail-bot
```

## 免责声明
本工具仅供学习和研究使用，使用风险自负。请遵守Parasail网络的使用条款和相关法律法规。

## 作者信息
脚本作者: fishzone24  
推特: https://x.com/fishzone24  
此脚本为免费开源脚本，如有问题请提交issue
