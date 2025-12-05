#!/usr/bin/env python3
import requests
import threading
import queue
import random
import ipaddress
import urllib3

# ---------- 屏蔽 HTTPS 警告 ----------
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

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
]
max_threads = 20   # 并发线程数
timeout = 5        # 请求超时

q = queue.Queue()
results = []

# ---------- 读取 IP 文件，并展开 IP 段 ----------
with open(ip_file) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            # 自动解析单个 IP 或 CIDR 段
            net = ipaddress.ip_network(line, strict=False)
            for ip in net.hosts():  # 遍历可用主机
                q.put(str(ip))
        except ValueError:
            print(f"无效 IP 或段: {line}")

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
                # 如果 HEAD 不支持，再用 GET 流模式
                resp = requests.get(url, headers=headers, timeout=timeout, verify=False, stream=True)
            
            if resp.status_code == 200:
                print(f"OK: {ip} -> {domain} (status {resp.status_code})")
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

# ---------- 等待完成 ----------
for t in threads:
    t.join()

# ---------- 写入结果 ----------
with open(output_file, "w") as f:
    for ip in results:
        f.write(ip + "\n")

print(f"检测完成，可用 IP 写入 {output_file}")
