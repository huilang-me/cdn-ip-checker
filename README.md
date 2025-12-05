# CDN IP Checker (GitHub Actions)

本项目用于批量检测 `ip.txt` 中的 IP 或 IP 段，判断它们是否可以作为 CDN 节点访问指定域名（例如 example.com）。

通过 GitHub Actions 自动定时执行：
- 解析 ip.txt
- 使用 curl 强制域名绑定到指定 IP (`--resolve`)
- 访问 https://example.com
- 根据响应判断该 IP 是否可用
- 将可用结果写入 valid_ips.txt
- 自动提交到仓库

---

## 文件说明

```
.
├── ip.txt                # 输入 IP 列表（每行一个 IP）
├── check.sh              # 检测脚本
├── valid_ips.txt         # 自动生成：可用 IP 结果
└── .github/
    └── workflows/
        └── check.yml     # GitHub Actions 配置
```

---

## 使用方法

1. Fork 本仓库
2. 编辑 `ip.txt` 添加你要检测的 IP 或 IP 段
3. 修改 `check.sh` 里的 DOMAIN="example.com" 为你自己的域名
4. GitHub Actions 会自动定时执行（每 6 小时）
5. 结果自动写入 `valid_ips.txt`

---

## 手动触发检测

在 GitHub → Actions → `Check CDN IPs` → Run workflow

---

## 修改检测关键字

在 `check.sh` 中：

```bash
if echo "$response" | grep -q "Example Domain"; then
```

你可以改为你网站 HTML 中固定存在的字符串。

---

## 示例

`ip.txt`:

```
104.21.1.1
172.67.2.2
8.8.8.8
```

运行结束后 `valid_ips.txt` 可能如下：

```
104.21.1.1
172.67.2.2
```

---

## License

MIT
