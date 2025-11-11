# 脚本说明

## 生成隐私政策页面

运行以下命令生成中文隐私政策页面：

```bash
./generate_privacy_policy.sh
```

运行以下命令生成英文隐私政策页面：

```bash
./generate_privacy_policy_en.sh
```

运行以下命令生成法文隐私政策页面：

```bash
./generate_privacy_policy_fr.sh
```

生成的隐私政策页面将位于：
- 中文版：`docs/privacy-policy.html`
- 英文版：`docs/privacy-policy-en.html`
- 法文版：`docs/privacy-policy-fr.html`

都可以用于 GitHub Pages 发布。

## GitHub Pages 配置

1. 确保在 GitHub 仓库设置中将 GitHub Pages 源设置为 docs/ 目录：
   - 设置路径: Settings -> Pages -> Source -> 选择 'deploy from a branch' -> Branch 选择 'main' -> Folder 选择 '/docs'

2. 隐私政策页面的访问地址将是：
   - 中文版：`https://[username].github.io/[repository]/privacy-policy.html`
   - 英文版：`https://[username].github.io/[repository]/privacy-policy-en.html`
   - 法文版：`https://[username].github.io/[repository]/privacy-policy-fr.html`

例如：
- 中文版：https://SimonLiu2016.github.io/dualvpn_manager/privacy-policy.html
- 英文版：https://SimonLiu2016.github.io/dualvpn_manager/privacy-policy-en.html
- 法文版：https://SimonLiu2016.github.io/dualvpn_manager/privacy-policy-fr.html