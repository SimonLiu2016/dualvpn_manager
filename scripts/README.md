# 脚本说明

## 生成隐私政策页面

运行以下命令生成隐私政策页面：

```bash
./generate_privacy_policy.sh
```

生成的隐私政策页面将位于 `docs/privacy-policy.html`，可以用于 GitHub Pages 发布。

## GitHub Pages 配置

1. 确保在 GitHub 仓库设置中将 GitHub Pages 源设置为 docs/ 目录：
   - 设置路径: Settings -> Pages -> Source -> 选择 'deploy from a branch' -> Branch 选择 'main' -> Folder 选择 '/docs'

2. 隐私政策页面的访问地址将是：
   `https://[username].github.io/[repository]/privacy-policy.html`

例如：https://SimonLiu2016.github.io/dualvpn_manager/privacy-policy.html