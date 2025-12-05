#!/usr/bin/env python3
import requests
import threading
import queue
import random
import ipaddress
import urllib3

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
timeout = 5

q = queue.Queue()
results = []

# ---------- 屏蔽 HTTPS 警告 ----------
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

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

# ---------- 判断是否 Cloudflare CDN ----------
def is_cloudflare(headers):
    server = headers.get("Server", "").lower()
    cf_ray = headers.get("CF-RAY")
    cf_cache = headers.get("CF-Cache-Status")
    # 只要 Server 是 cloudflare 或存在 CF-RAY 就认为是 Cloudflare 节点
    return "cloudflare" in server or cf_ray is not None

# ---------- 线程函数 ----------
def worker():
    while not q.empty():
        ip = q.get()
        domain = random.choice(domains)
        try:
            url = f"https://{domain}"
            headers = {"Host": domain}

            # HEAD 请求优先
            resp = requests.head(url, headers=headers, timeout=timeout, verify=False)
            if resp.status_code != 200:
                # GET 流模式 fallback
                resp = requests.get(url, headers=headers, timeout=timeout, verify=False, stream=True)
            
            # ✅ 打印返回头
            print(f"\n--- {ip} -> {domain} ---")
            for k, v in resp.headers.items():
                print(f"{k}: {v}")

            if resp.status_code == 200 and is_cloudflare(resp.headers):
                print(f"Cloudflare OK: {ip} -> {domain}")
                results.append(ip)
            else:
                print(f"FAIL: {ip} -> {domain} (status {resp.status_code})")
            resp.close()
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

print(f"检测完成，可用 Cloudflare IP 写入 {output_file}")
