#!/usr/bin/env python3
import requests
import threading
import queue
import random

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
timeout = 5

q = queue.Queue()
results = []

with open(ip_file) as f:
    for line in f:
        ip = line.strip()
        if ip:
            q.put(ip)

def worker():
    while not q.empty():
        ip = q.get()
        domain = random.choice(domains)
        try:
            url = f"https://{domain}"
            headers = {"Host": domain}

            # ✅ HEAD 请求或者 GET 流模式
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

threads = []
for _ in range(max_threads):
    t = threading.Thread(target=worker)
    t.start()
    threads.append(t)

for t in threads:
    t.join()

with open(output_file, "w") as f:
    for ip in results:
        f.write(ip + "\n")

print(f"检测完成，可用 IP 写入 {output_file}")
