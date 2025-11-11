#!/bin/bash

# 生成隐私政策页面的脚本
# 用于为 Mac App Store 发布准备隐私政策页面

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 获取项目根目录
PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)

# 输出目录
DOCS_DIR="$PROJECT_ROOT/docs"
PRIVACY_POLICY_FILE="$DOCS_DIR/privacy-policy.html"

# 从 pubspec.yaml 获取应用信息
APP_NAME=$(grep "^name:" "$PROJECT_ROOT/pubspec.yaml" | cut -d ':' -f 2 | tr -d ' ')
APP_DESCRIPTION=$(grep "^description:" "$PROJECT_ROOT/pubspec.yaml" | cut -d '"' -f 2)
APP_VERSION=$(grep "^version:" "$PROJECT_ROOT/pubspec.yaml" | cut -d ':' -f 2 | tr -d ' ')
HOMEPAGE=$(grep "^homepage:" "$PROJECT_ROOT/pubspec.yaml" | cut -d ':' -f 2 | tr -d ' ')

echo -e "${GREEN}开始生成隐私政策页面...${NC}"

# 创建 docs 目录（如果不存在）
if [ ! -d "$DOCS_DIR" ]; then
    echo -e "${YELLOW}创建 docs 目录...${NC}"
    mkdir -p "$DOCS_DIR"
fi

# 生成隐私政策 HTML 页面
cat > "$PRIVACY_POLICY_FILE" << EOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>隐私政策 - $APP_NAME</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Open Sans', 'Helvetica Neue', sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f8f9fa;
        }
        .container {
            background-color: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #2c3e50;
            border-bottom: 2px solid #3498db;
            padding-bottom: 10px;
        }
        h2 {
            color: #34495e;
            margin-top: 30px;
        }
        h3 {
            color: #7f8c8d;
            margin-top: 25px;
        }
        p {
            margin-bottom: 15px;
        }
        ul, ol {
            margin-bottom: 20px;
            padding-left: 30px;
        }
        li {
            margin-bottom: 10px;
        }
        .contact-info {
            background-color: #e8f4fc;
            padding: 15px;
            border-radius: 5px;
            margin: 20px 0;
        }
        .footer {
            text-align: center;
            margin-top: 30px;
            color: #7f8c8d;
            font-size: 0.9em;
        }
        .last-updated {
            text-align: right;
            color: #95a5a6;
            font-style: italic;
            margin-top: 30px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>$APP_NAME 隐私政策</h1>
        
        <p>生效日期：$(date +"%Y年%m月%d日")</p>
        
        <p>感谢您选择使用 $APP_NAME（以下简称"本应用"）。本隐私政策旨在向您说明我们如何收集、使用、存储和保护您的个人信息，以及您享有的相关权利。请您在使用本应用前仔细阅读并理解本隐私政策。</p>
        
        <h2>一、信息收集</h2>
        
        <h3>1.1 我们收集的信息</h3>
        <p>为了提供和优化本应用的服务，我们可能会收集以下类型的个人信息：</p>
        <ul>
            <li><strong>设备信息</strong>：包括设备型号、操作系统版本、唯一设备标识符等</li>
            <li><strong>应用使用信息</strong>：包括应用功能使用情况、错误日志、性能数据等</li>
            <li><strong>网络信息</strong>：包括IP地址、网络连接状态等</li>
        </ul>
        
        <h3>1.2 VPN配置信息</h3>
        <p>本应用作为VPN管理工具，会处理您的VPN配置信息，包括但不限于：</p>
        <ul>
            <li>VPN服务器地址和端口</li>
            <li>认证信息（用户名、密码等）</li>
            <li>加密密钥和证书</li>
            <li>路由规则配置</li>
        </ul>
        <p><strong>重要提示</strong>：上述VPN配置信息仅在您的设备本地存储和处理，我们不会收集、传输或存储您的VPN配置信息到任何服务器。</p>
        
        <h2>二、信息使用</h2>
        
        <p>我们收集的信息将用于以下目的：</p>
        <ul>
            <li>提供、维护和改进本应用的功能和服务</li>
            <li>诊断和修复技术问题</li>
            <li>优化用户体验</li>
            <li>检测和防止欺诈或滥用行为</li>
            <li>遵守法律法规要求</li>
        </ul>
        
        <h2>三、信息共享</h2>
        
        <p>我们承诺不会将您的个人信息出售、交易或转让给第三方。但在以下情况下，我们可能会共享您的信息：</p>
        <ul>
            <li><strong>服务提供商</strong>：我们可能会与受信任的第三方服务提供商共享信息，以协助我们提供服务（如数据分析、错误监控等）</li>
            <li><strong>法律要求</strong>：当法律、法规或政府机关要求时，我们可能会披露相关信息</li>
            <li><strong>业务转让</strong>：在涉及合并、收购或资产出售的情况下，您的信息可能会被转移</li>
        </ul>
        
        <h2>四、数据安全</h2>
        
        <p>我们采取适当的技术和组织措施来保护您的个人信息安全，防止未经授权的访问、使用或披露。但请注意，没有任何互联网传输或电子存储方法是100%安全的，我们无法保证绝对安全。</p>
        
        <h2>五、您的权利</h2>
        
        <p>根据相关法律法规，您享有以下权利：</p>
        <ul>
            <li>访问、更正或删除您的个人信息</li>
            <li>撤回同意</li>
            <li>限制或反对处理您的个人信息</li>
            <li>数据可携带权</li>
        </ul>
        <p>如需行使上述权利，请通过本政策末尾提供的联系方式与我们联系。</p>
        
        <h2>六、数据保留</h2>
        
        <p>我们仅在实现本隐私政策所述目的所需的期限内保留您的个人信息，除非法律要求或允许更长的保留期。</p>
        
        <h2>七、儿童隐私</h2>
        
        <p>本应用不面向14岁以下的儿童提供服务，我们不会故意收集儿童的个人信息。如我们发现无意中收集了儿童信息，将立即删除。</p>
        
        <h2>八、隐私政策变更</h2>
        
        <p>我们可能会适时更新本隐私政策。如有重大变更，我们将在应用内或通过其他适当方式通知您。</p>
        
        <h2>九、联系我们</h2>
        
        <div class="contact-info">
            <p>如您对本隐私政策有任何疑问、意见或建议，或需要行使您的个人信息权利，请通过以下方式联系我们：</p>
            <p><strong>电子邮件</strong>：582883825@qq.com</p>
            <p><strong>项目主页</strong>：<a href="$HOMEPAGE">$HOMEPAGE</a></p>
        </div>
        
        <h2>十、其他</h2>
        
        <p>本隐私政策的解释权归本应用开发者所有。</p>
        
        <div class="last-updated">
            <p>最后更新时间：$(date +"%Y年%m月%d日")</p>
        </div>
        
        <div class="footer">
            <p>$APP_NAME $APP_VERSION</p>
            <p>© $(date +"%Y") 本应用开发者。保留所有权利。</p>
        </div>
    </div>
</body>
</html>
EOF

echo -e "${GREEN}隐私政策页面已成功生成！${NC}"
echo -e "文件位置: ${YELLOW}$PRIVACY_POLICY_FILE${NC}"

# 检查是否已配置 GitHub Pages
if [ -d "$PROJECT_ROOT/.git" ]; then
    echo -e "\n${YELLOW}检查 GitHub Pages 配置...${NC}"
    
    # 检查是否已设置 GitHub Pages 源为 docs/
    echo -e "${GREEN}请确保在 GitHub 仓库设置中将 GitHub Pages 源设置为 docs/ 目录。${NC}"
    echo -e "${GREEN}设置路径: Settings -> Pages -> Source -> 选择 'deploy from a branch' -> Branch 选择 'main' -> Folder 选择 '/docs'${NC}"
    
    echo -e "\n${GREEN}隐私政策页面的访问地址将是:${NC}"
    REPO_NAME=$(basename -s .git "$(git remote get-url origin)" 2>/dev/null || echo "dualvpn_manager")
    echo -e "${YELLOW}https://$(git remote get-url origin 2>/dev/null | sed 's/.*:\/\/github.com\///' | sed 's/\.git$//' | cut -d'/' -f1).github.io/$REPO_NAME/privacy-policy.html${NC}"
fi

echo -e "\n${GREEN}隐私政策生成完成！${NC}"