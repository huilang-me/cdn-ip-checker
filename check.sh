#!/usr/bin/env python3
import subprocess
import threading
import queue
import random
import ipaddress

# ---------- 配置 ----------
ip_file = "ip.txt"
output_file = "valid_ips.txt"
domains = [
    "www.cloudflare.com",
    "www.shopify.com",
    "ip.sb",
    "japan.com",
    "visa.com.hk",
    "www.visa.com.tw",
    "www.visa.co.jp",
    "www.visakorea.com",
    "www.visakorea.com",
    "www.gco.gov.qa",
    "www.gov.se",
    "www.gov.ua",
    "store.ubi.com",
    "www.nexusmods.com",
    "wall.alphacoders.com",
    "discord.com",
]  # 可以随机选择
max_threads = 100
timeout = 3  # curl 超时（秒）

q = queue.Queue()
results = []

# ---------- 读取 IP 文件并展开 ----------
with open(ip_file) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            net = ipaddress.ip_network(line, strict=False)
            for ip in net.hosts():
                q.put(str(ip))
        except ValueError:
            print(f"无效 IP 或段: {line}")

# ---------- 判断 Cloudflare CDN ----------
def is_cloudflare(headers_lines):
    # 简单判断：Server 头含 cloudflare 或 CF-RAY 存在
    for line in headers_lines:
        line = line.strip()
        if line.lower().startswith("server:") and "cloudflare" in line.lower():
            return True
        if line.startswith("CF-RAY:") or line.startswith("cf-ray:"):
            return True
    return False

# ---------- 线程函数 ----------
def worker():
    while not q.empty():
        ip = q.get()
        domain = random.choice(domains)
        
        # 优化：只在成功或失败时打印，减少 I/O 
        
        try:
            cmd = [
                "curl",
                "-s",                 # 静默
                # "-D", "-",            # 打印响应头
                # "-o", "/dev/null",    # 不输出 body
                "-I",           # 发送 HEAD 请求，只返回响应头（代替 -D - 和 -o /dev/null）
                "-m", str(timeout),   # 超时
                "--resolve", f"{domain}:443:{ip}",
                f"https://{domain}/"
            ]
            
            # 使用 check=True 来确保非零退出代码时抛出异常
            proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
            headers = proc.stdout.splitlines()

            # 检查 curl 是否成功（返回码 0）
            if proc.returncode == 0 and headers:
                if is_cloudflare(headers):
                    # 仅在成功时打印
                    print(f"Cloudflare OK: {ip} -> {domain}")
                    results.append(ip)
                else:
                    # 仅在不满足 Cloudflare 条件时打印失败
                    print(f"FAIL: {ip} -> {domain}")
            else:
                # 打印 curl 失败的原因（如超时、连接错误等）
                error_msg = proc.stderr.strip() if proc.stderr else "Connection error/Timeout"
                print(f"CURL ERROR ({proc.returncode}): {ip} -> {domain} : {error_msg}")

        except Exception as e:
            # 捕获其他 Python 级别的异常
            print(f"PYTHON ERROR: {ip} -> {domain} : {e}")
        finally:
            q.task_done()

# ---------- 启动线程 ----------
threads = []
for _ in range(max_threads):
    t = threading.Thread(target=worker)
    t.start()
    threads.append(t)

for t in threads:
    t.join()

# ---------- 写入结果 ----------
with open(output_file, "w") as f:
    for ip in results:
        f.write(ip + "\n")

print(f"\n检测完成，可用 Cloudflare IP 写入 {output_file}")
