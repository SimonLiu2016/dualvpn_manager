#!/bin/bash

# 生成法文隐私政策页面的脚本
# 用于为 Mac App Store 发布准备法文隐私政策页面

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
PRIVACY_POLICY_FILE="$DOCS_DIR/privacy-policy-fr.html"

# 从 pubspec.yaml 获取应用信息
APP_NAME=$(grep "^name:" "$PROJECT_ROOT/pubspec.yaml" | cut -d ':' -f 2 | tr -d ' ')
APP_DESCRIPTION=$(grep "^description:" "$PROJECT_ROOT/pubspec.yaml" | cut -d '"' -f 2)
APP_VERSION=$(grep "^version:" "$PROJECT_ROOT/pubspec.yaml" | cut -d ':' -f 2 | tr -d ' ')
HOMEPAGE=$(grep "^homepage:" "$PROJECT_ROOT/pubspec.yaml" | cut -d ':' -f 2 | tr -d ' ')

echo -e "${GREEN}开始生成法文隐私政策页面...${NC}"

# 创建 docs 目录（如果不存在）
if [ ! -d "$DOCS_DIR" ]; then
    echo -e "${YELLOW}创建 docs 目录...${NC}"
    mkdir -p "$DOCS_DIR"
fi

# 生成法文隐私政策 HTML 页面
cat > "$PRIVACY_POLICY_FILE" << EOF
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Politique de Confidentialité - $APP_NAME</title>
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
        <h1>Politique de Confidentialité de Dualvpn Manager</h1>
        
        <p>Date d'effet : $(date +"%d %B %Y" | sed 's/January/janvier/;s/February/février/;s/March/mars/;s/April/avril/;s/May/mai/;s/June/juin/;s/July/juillet/;s/August/août/;s/September/septembre/;s/October/octobre/;s/November/novembre/;s/December/décembre/')</p>
        
        <p>Merci d'avoir choisi d'utiliser Dualvpn Manager (ci-après dénommé "l'Application"). La présente Politique de Confidentialité a pour but de vous informer sur la manière dont nous collectons, utilisons, stockons et protégeons vos informations personnelles, ainsi que sur les droits dont vous disposez à cet égard. Veuillez lire attentivement et comprendre cette Politique de Confidentialité avant d'utiliser l'Application.</p>
        
        <h2>1. Collecte des Informations</h2>
        
        <h3>1.1 Informations que nous collectons</h3>
        <p>Afin de fournir et d'améliorer les services de l'Application, nous pouvons collecter les types d'informations personnelles suivants :</p>
        <ul>
            <li><strong>Informations sur l'appareil</strong> : Y compris le modèle de l'appareil, la version du système d'exploitation, les identifiants uniques de l'appareil, etc.</li>
            <li><strong>Informations sur l'utilisation de l'Application</strong> : Y compris l'utilisation des fonctionnalités de l'application, les journaux d'erreurs, les données de performance, etc.</li>
            <li><strong>Informations réseau</strong> : Y compris l'adresse IP, l'état de la connexion réseau, etc.</li>
        </ul>
        
        <h3>1.2 Informations de configuration VPN</h3>
        <p>En tant qu'outil de gestion VPN, l'Application traite vos informations de configuration VPN, notamment mais sans s'y limiter :</p>
        <ul>
            <li>Adresses et ports des serveurs VPN</li>
            <li>Informations d'authentification (noms d'utilisateur, mots de passe, etc.)</li>
            <li>Clés de chiffrement et certificats</li>
            <li>Configurations des règles de routage</li>
        </ul>
        <p><strong>Remarque importante</strong> : Les informations de configuration VPN mentionnées ci-dessus sont uniquement stockées et traitées localement sur votre appareil. Nous ne collectons, ne transmettons ni ne stockons vos informations de configuration VPN sur un serveur.</p>
        
        <h2>2. Utilisation des Informations</h2>
        
        <p>Les informations que nous collectons seront utilisées aux fins suivantes :</p>
        <ul>
            <li>Fournir, maintenir et améliorer les fonctionnalités et les services de l'Application</li>
            <li>Diagnostiquer et résoudre les problèmes techniques</li>
            <li>Optimiser l'expérience utilisateur</li>
            <li>Détecter et prévenir les comportements frauduleux ou abusifs</li>
            <li>Se conformer aux exigences légales et réglementaires</li>
        </ul>
        
        <h2>3. Partage des Informations</h2>
        
        <p>Nous nous engageons à ne pas vendre, échanger ou transférer vos informations personnelles à des tiers. Cependant, nous pouvons partager vos informations dans les circonstances suivantes :</p>
        <ul>
            <li><strong>Prestataires de services</strong> : Nous pouvons partager des informations avec des prestataires de services tiers de confiance pour nous aider à fournir des services (tels que l'analyse de données, la surveillance des erreurs, etc.)</li>
            <li><strong>Exigences légales</strong> : Nous pouvons divulguer des informations pertinentes lorsque la loi, les réglementations ou les autorités gouvernementales l'exigent</li>
            <li><strong>Transferts d'entreprise</strong> : En cas de fusion, d'acquisition ou de vente d'actifs, vos informations peuvent être transférées</li>
        </ul>
        
        <h2>4. Sécurité des Données</h2>
        
        <p>Nous employons des mesures techniques et organisationnelles appropriées pour protéger la sécurité de vos informations personnelles et prévenir tout accès, utilisation ou divulgation non autorisé(e). Cependant, veuillez noter qu'aucune méthode de transmission Internet ou de stockage électronique n'est sécurisée à 100 %, et nous ne pouvons garantir une sécurité absolue.</p>
        
        <h2>5. Vos Droits</h2>
        
        <p>Conformément aux lois et réglementations applicables, vous disposez des droits suivants :</p>
        <ul>
            <li>Accéder à vos informations personnelles, les corriger ou les supprimer</li>
            <li>Retirer votre consentement</li>
            <li>Restreindre ou vous opposer au traitement de vos informations personnelles</li>
            <li>Droit à la portabilité des données</li>
        </ul>
        <p>Si vous souhaitez exercer les droits susmentionnés, veuillez nous contacter via les coordonnées fournies à la fin de cette politique.</p>
        
        <h2>6. Conservation des Données</h2>
        
        <p>Nous conservons vos informations personnelles uniquement aussi longtemps que nécessaire pour remplir les objectifs décrits dans la présente Politique de Confidentialité, sauf si une période de conservation plus longue est requise ou autorisée par la loi.</p>
        
        <h2>7. Vie Privée des Enfants</h2>
        
        <p>L'Application n'est pas destinée aux enfants de moins de 14 ans, et nous ne collectons pas sciemment d'informations personnelles auprès d'enfants. Si nous découvrons que nous avons involontairement collecté des informations auprès d'un enfant, nous les supprimerons immédiatement.</p>
        
        <h2>8. Modifications de la Politique de Confidentialité</h2>
        
        <p>Nous pouvons mettre à jour cette Politique de Confidentialité de temps à autre. En cas de changements importants, nous vous en informerons via l'Application ou par d'autres moyens appropriés.</p>
        
        <h2>9. Nous Contacter</h2>
        
        <div class="contact-info">
            <p>Si vous avez des questions, commentaires ou suggestions concernant cette Politique de Confidentialité, ou si vous devez exercer vos droits en matière d'informations personnelles, veuillez nous contacter par les moyens suivants :</p>
            <p><strong>E-mail</strong> : 582883825@qq.com</p>
            <p><strong>Page d'accueil du projet</strong> : <a href="$HOMEPAGE">$HOMEPAGE</a></p>
        </div>
        
        <h2>10. Divers</h2>
        
        <p>Les droits d'interprétation de la présente Politique de Confidentialité appartiennent au développeur de l'Application.</p>
        
        <div class="last-updated">
            <p>Dernière mise à jour : $(date +"%d %B %Y" | sed 's/January/janvier/;s/February/février/;s/March/mars/;s/April/avril/;s/May/mai/;s/June/juin/;s/July/juillet/;s/August/août/;s/September/septembre/;s/October/octobre/;s/November/novembre/;s/December/décembre/')</p>
        </div>
        
        <div class="footer">
            <p>Dualvpn Manager $APP_VERSION</p>
            <p>© $(date +"%Y") Développeur de l'Application. Tous droits réservés.</p>
        </div>
    </div>
</body>
</html>
EOF

echo -e "${GREEN}法文隐私政策页面已成功生成！${NC}"
echo -e "文件位置: ${YELLOW}$PRIVACY_POLICY_FILE${NC}"

# 检查是否已配置 GitHub Pages
if [ -d "$PROJECT_ROOT/.git" ]; then
    echo -e "\n${YELLOW}检查 GitHub Pages 配置...${NC}"
    
    # 检查是否已设置 GitHub Pages 源为 docs/
    echo -e "${GREEN}请确保在 GitHub 仓库设置中将 GitHub Pages 源设置为 docs/ 目录。${NC}"
    echo -e "${GREEN}设置路径: Settings -> Pages -> Source -> 选择 'deploy from a branch' -> Branch 选择 'main' -> Folder 选择 '/docs'${NC}"
    
    echo -e "\n${GREEN}法文隐私政策页面的访问地址将是:${NC}"
    REPO_NAME=$(basename -s .git "$(git remote get-url origin)" 2>/dev/null || echo "dualvpn_manager")
    echo -e "${YELLOW}https://$(git remote get-url origin 2>/dev/null | sed 's/.*:\/\/github.com\///' | sed 's/\.git$//' | cut -d'/' -f1).github.io/$REPO_NAME/privacy-policy-fr.html${NC}"
fi

echo -e "\n${GREEN}法文隐私政策生成完成！${NC}"