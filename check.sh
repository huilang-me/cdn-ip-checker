#!/usr/bin/env python3
import subprocess
import threading
import queue
import random
import ipaddress
import time

# ---------------- 配置 ----------------
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
]

max_threads = 100
timeout = 5

# --------------------------------------
task_queue = queue.Queue()
result_list = []
lock = threading.Lock()


# ---------------- 工具函数 ----------------
def parse_status(headers):
    """解析 HTTP 状态码"""
    if not headers:
        return None
    line = headers[0].strip()
    if line.startswith("HTTP/"):
        parts = line.split()
        if len(parts) >= 2:
            return int(parts[1])
    return None


def is_cloudflare(headers):
    """检查是否 Cloudflare"""
    for line in headers:
        if line.lower().startswith("cf-ray:"):
            return True
    return False


# ---------------- 线程 worker ----------------
def worker():
    while not task_queue.empty():
        ip = task_queue.get()
        domain = random.choice(domains)

        try:
            cmd = [
                "curl",
                "-s",
                "-I",
                "--fail-early",
                "-m", str(timeout),
                "--resolve", f"{domain}:443:{ip}",
                f"https://{domain}/"
            ]

            start = time.time()
            proc = subprocess.run(cmd, capture_output=True, text=True)
            end = time.time()

            headers = proc.stdout.splitlines()
            status = parse_status(headers)

            if proc.returncode == 0 and status in (200, 403) and is_cloudflare(headers):
                cost = round((end - start) * 1000, 2)

                with lock:
                    result_list.append((ip, cost))

                print(f"[OK] {ip} | {domain} | 200 | {cost} ms")
            else:
                print(f"[FAIL] {ip} | {domain} | status={status}")

        except Exception as e:
            print(f"[ERROR] {ip} : {e}")

        finally:
            task_queue.task_done()


# ---------------- 扫描 IP 文件 ----------------
with open(ip_file) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            net = ipaddress.ip_network(line, strict=False)
            for ip in net.hosts():
                task_queue.put(str(ip))
        except ValueError:
            print(f"无效 IP/段: {line}")


# ---------------- 启动线程 ----------------
threads = []
for _ in range(max_threads):
    t = threading.Thread(target=worker)
    t.start()
    threads.append(t)

for t in threads:
    t.join()


# ---------------- 保存结果 ----------------
# 按响应时间排序（最快的 Cloudflare IP 在前）
result_list.sort(key=lambda x: x[1])

with open(output_file, "w") as f:
    for ip, cost in result_list:
        # f.write(f"{ip}    {cost}ms\n")
        f.write(ip + "\n")

print(f"\n✔ 扫描完成，成功 {len(result_list)} 个 Cloudflare IP 已写入：{output_file}")
