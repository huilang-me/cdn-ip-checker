#!/usr/bin/env python3
import requests
import threading
import queue
import random
import time

# ---------- 配置 ----------
ip_file = "ip.txt"
output_file = "valid_ips.txt"
domains = ["www.cloudflare.com", "www.shopify.com", "ip.sb", "japan.com", "visa.com.hk","www.visa.com.tw"]  # 可随机选择
max_threads = 10   # 并发线程数
timeout = 5        # 请求超时
keyword = "Example Domain"  # 判断响应是否成功的关键字

# ---------- 全局队列 ----------
q = queue.Queue()
results = []

# ---------- 读取 IP 文件 ----------
with open(ip_file) as f:
    for line in f:
        ip = line.strip()
        if ip:
            q.put(ip)

# ---------- 线程函数 ----------
def worker():
    while not q.empty():
        ip = q.get()
        domain = random.choice(domains)
        try:
            url = f"https://{domain}"
            headers = {"Host": domain}
            # 使用 requests 直接发请求，不同域名随机
            resp = requests.get(url, headers=headers, timeout=timeout, verify=False)
            if keyword in resp.text:
                print(f"OK: {ip} -> {domain}")
                results.append(ip)
            else:
                print(f"FAIL: {ip} -> {domain}")
        except Exception as e:
            print(f"ERROR: {ip} -> {domain} : {e}")
        finally:
            q.task_done()
        time.sleep(0.1)  # 可选，防止请求过快

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
