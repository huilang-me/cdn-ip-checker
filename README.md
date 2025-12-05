# Cloudflare CDN IP Checker

本项目用于扫描指定 IP 段，判断哪些 IP 属于 **Cloudflare CDN 节点**，并自动生成可用 IP 列表。  
支持 GitHub Actions 定时执行，并可将结果安全保存或推送回仓库。

---

## 功能

1. **IP 段扫描**  
   - 支持单个 IP 或 CIDR 段（如 `104.16.0.0/20`）
   - 自动展开 IP 段进行检测  

2. **Cloudflare CDN 判断**  
   - 使用 `curl --resolve` 将域名请求绑定到指定 IP（类似修改 Host）  
   - 检查 HTTP 响应头：
     - `Server: cloudflare`
     - 或存在 `CF-RAY`  
   - 确认 IP 是否属于 Cloudflare CDN  

3. **多线程加速**  
   - 可配置 `max_threads`，快速扫描大量 IP  

4. **随机域名**  
   - 支持多个目标域名随机选择，避免单点异常  

5. **日志打印**  
   - 每个 IP 的完整响应头都会打印，便于调试  

6. **结果保存**  
   - 输出 `valid_ips.txt`，每行一个可用 Cloudflare IP  
   - 可通过 GitHub Actions 自动上传 artifact 或安全 push 回仓库  

---

## 文件说明

| 文件 | 说明 |
|------|------|
| `check.sh` | Bash 脚本，调用 Python 脚本进行检测 |
| `check.py` | Python 多线程检测脚本，使用 `curl --resolve` |
| `ip.txt` | 待检测的 IP 段文件，每行一个 IP 或 CIDR |
| `valid_ips.txt` | 检测完成后生成的有效 Cloudflare IP 列表 |
| `.github/workflows/check.yml` | GitHub Actions workflow，支持定时运行和手动触发 |

---

## 使用方法

### 1. 准备 IP 文件

在项目根目录创建 `ip.txt`，每行一个 IP 或 IP 段：

```text
104.16.0.0/20
104.24.0.0/20
