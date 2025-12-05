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
    "www.visa.com.tw"
]  # 可以随机选择
max_threads = 20
timeout = 5  # curl 超时（秒）

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
        try:
            # curl 命令，绑定 IP 并打印响应头
            cmd = [
                "curl",
                "-s",                 # 静默
                "-D", "-",            # 打印响应头
                "-o", "/dev/null",    # 不输出 body
                "-m", str(timeout),   # 超时
                "--resolve", f"{domain}:443:{ip}",
                f"https://{domain}/"
            ]
            proc = subprocess.run(cmd, capture_output=True, text=True)
            headers = proc.stdout.splitlines()

            # 打印完整返回头
            print(f"\n--- {ip} -> {domain} ---")
            for h in headers:
                print(h)

            if is_cloudflare(headers):
                print(f"Cloudflare OK: {ip} -> {domain}")
                results.append(ip)
            else:
                print(f"FAIL: {ip} -> {domain}")

        except Exception as e:
            print(f"ERROR: {ip} -> {domain} : {e}")
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
