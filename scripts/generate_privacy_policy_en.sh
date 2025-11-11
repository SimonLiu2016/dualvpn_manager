#!/bin/bash

# 生成英文隐私政策页面的脚本
# 用于为 Mac App Store 发布准备英文隐私政策页面

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
PRIVACY_POLICY_FILE="$DOCS_DIR/privacy-policy-en.html"

# 从 pubspec.yaml 获取应用信息
APP_NAME=$(grep "^name:" "$PROJECT_ROOT/pubspec.yaml" | cut -d ':' -f 2 | tr -d ' ')
APP_DESCRIPTION=$(grep "^description:" "$PROJECT_ROOT/pubspec.yaml" | cut -d '"' -f 2)
APP_VERSION=$(grep "^version:" "$PROJECT_ROOT/pubspec.yaml" | cut -d ':' -f 2 | tr -d ' ')
HOMEPAGE=$(grep "^homepage:" "$PROJECT_ROOT/pubspec.yaml" | cut -d ':' -f 2 | tr -d ' ')

echo -e "${GREEN}开始生成英文隐私政策页面...${NC}"

# 创建 docs 目录（如果不存在）
if [ ! -d "$DOCS_DIR" ]; then
    echo -e "${YELLOW}创建 docs 目录...${NC}"
    mkdir -p "$DOCS_DIR"
fi

# 生成英文隐私政策 HTML 页面
cat > "$PRIVACY_POLICY_FILE" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Privacy Policy - $APP_NAME</title>
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
        <h1>$APP_NAME Privacy Policy</h1>
        
        <p>Effective Date: $(date +"%B %d, %Y")</p>
        
        <p>Thank you for choosing to use $APP_NAME (hereinafter referred to as "the Application"). This Privacy Policy is intended to inform you how we collect, use, store, and protect your personal information, as well as the rights you have in relation thereto. Please read this Privacy Policy carefully and understand it before using the Application.</p>
        
        <h2>1. Information Collection</h2>
        
        <h3>1.1 Information We Collect</h3>
        <p>To provide and improve the services of the Application, we may collect the following types of personal information:</p>
        <ul>
            <li><strong>Device Information</strong>: Including device model, operating system version, unique device identifiers, etc.</li>
            <li><strong>Application Usage Information</strong>: Including application feature usage, error logs, performance data, etc.</li>
            <li><strong>Network Information</strong>: Including IP address, network connection status, etc.</li>
        </ul>
        
        <h3>1.2 VPN Configuration Information</h3>
        <p>As a VPN management tool, the Application processes your VPN configuration information, including but not limited to:</p>
        <ul>
            <li>VPN server addresses and ports</li>
            <li>Authentication information (usernames, passwords, etc.)</li>
            <li>Encryption keys and certificates</li>
            <li>Routing rule configurations</li>
        </ul>
        <p><strong>Important Notice</strong>: The aforementioned VPN configuration information is only stored and processed locally on your device. We do not collect, transmit, or store your VPN configuration information to any server.</p>
        
        <h2>2. Information Use</h2>
        
        <p>The information we collect will be used for the following purposes:</p>
        <ul>
            <li>To provide, maintain, and improve the functionality and services of the Application</li>
            <li>To diagnose and fix technical issues</li>
            <li>To optimize user experience</li>
            <li>To detect and prevent fraudulent or abusive behaviors</li>
            <li>To comply with legal and regulatory requirements</li>
        </ul>
        
        <h2>3. Information Sharing</h2>
        
        <p>We commit not to sell, trade, or transfer your personal information to third parties. However, we may share your information in the following circumstances:</p>
        <ul>
            <li><strong>Service Providers</strong>: We may share information with trusted third-party service providers to assist us in providing services (such as data analysis, error monitoring, etc.)</li>
            <li><strong>Legal Requirements</strong>: We may disclose relevant information when required by laws, regulations, or government agencies</li>
            <li><strong>Business Transfers</strong>: In the event of a merger, acquisition, or sale of assets, your information may be transferred</li>
        </ul>
        
        <h2>4. Data Security</h2>
        
        <p>We employ appropriate technical and organizational measures to protect the security of your personal information and prevent unauthorized access, use, or disclosure. However, please note that no method of internet transmission or electronic storage is 100% secure, and we cannot guarantee absolute security.</p>
        
        <h2>5. Your Rights</h2>
        
        <p>In accordance with applicable laws and regulations, you have the following rights:</p>
        <ul>
            <li>Access, correct, or delete your personal information</li>
            <li>Withdraw consent</li>
            <li>Restrict or object to the processing of your personal information</li>
            <li>Data portability</li>
        </ul>
        <p>If you wish to exercise the above rights, please contact us through the contact information provided at the end of this policy.</p>
        
        <h2>6. Data Retention</h2>
        
        <p>We retain your personal information only for as long as necessary to fulfill the purposes described in this Privacy Policy, unless a longer retention period is required or permitted by law.</p>
        
        <h2>7. Children's Privacy</h2>
        
        <p>The Application is not intended for children under the age of 14, and we do not knowingly collect personal information from children. If we discover that we have inadvertently collected information from a child, we will promptly delete it.</p>
        
        <h2>8. Changes to Privacy Policy</h2>
        
        <p>We may update this Privacy Policy from time to time. In the event of significant changes, we will notify you through the Application or by other appropriate means.</p>
        
        <h2>9. Contact Us</h2>
        
        <div class="contact-info">
            <p>If you have any questions, comments, or suggestions regarding this Privacy Policy, or if you need to exercise your personal information rights, please contact us through the following methods:</p>
            <p><strong>Email</strong>: 582883825@qq.com</p>
            <p><strong>Project Homepage</strong>: <a href="$HOMEPAGE">$HOMEPAGE</a></p>
        </div>
        
        <h2>10. Miscellaneous</h2>
        
        <p>The interpretation right of this Privacy Policy belongs to the developer of the Application.</p>
        
        <div class="last-updated">
            <p>Last Updated: $(date +"%B %d, %Y")</p>
        </div>
        
        <div class="footer">
            <p>$APP_NAME $APP_VERSION</p>
            <p>© $(date +"%Y") Application Developer. All rights reserved.</p>
        </div>
    </div>
</body>
</html>
EOF

echo -e "${GREEN}英文隐私政策页面已成功生成！${NC}"
echo -e "文件位置: ${YELLOW}$PRIVACY_POLICY_FILE${NC}"

# 检查是否已配置 GitHub Pages
if [ -d "$PROJECT_ROOT/.git" ]; then
    echo -e "\n${YELLOW}检查 GitHub Pages 配置...${NC}"
    
    # 检查是否已设置 GitHub Pages 源为 docs/
    echo -e "${GREEN}请确保在 GitHub 仓库设置中将 GitHub Pages 源设置为 docs/ 目录。${NC}"
    echo -e "${GREEN}设置路径: Settings -> Pages -> Source -> 选择 'deploy from a branch' -> Branch 选择 'main' -> Folder 选择 '/docs'${NC}"
    
    echo -e "\n${GREEN}英文隐私政策页面的访问地址将是:${NC}"
    REPO_NAME=$(basename -s .git "$(git remote get-url origin)" 2>/dev/null || echo "dualvpn_manager")
    echo -e "${YELLOW}https://$(git remote get-url origin 2>/dev/null | sed 's/.*:\/\/github.com\///' | sed 's/\.git$//' | cut -d'/' -f1).github.io/$REPO_NAME/privacy-policy-en.html${NC}"
fi

echo -e "\n${GREEN}英文隐私政策生成完成！${NC}"