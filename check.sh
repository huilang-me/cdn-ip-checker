#!/usr/bin/env python3
import subprocess
import threading
import queue
import random
import ipaddress
import time

# ---------------- 配置 ----------------
ip_file = "ips.txt"
output_file = "valid_ips.txt"

# 目标域名列表 (随机选择一个进行测试)
domains = [
    "www.cloudflare.com",
    "www.shopify.com",
    "ip.sb",
    "japan.com",
    "visa.com.hk",
    "www.visa.com.tw",
    "www.visa.co.jp",
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
timeout = 5  # curl 命令超时时间（秒）
output_with_latency = False  # True 输出 IP + 延迟，False 只输出 IP

# --------------------------------------
task_queue = queue.Queue()
result_list = []
lock = threading.Lock()  # 用于保护 result_list 的互斥锁
seen_ips = set()  # 去重 IP

# ---------------- 工具函数 ----------------
def parse_status(headers):
    """解析 HTTP 状态码"""
    if not headers:
        return None
    line = headers[0].strip()
    if line.startswith("HTTP/"):
        try:
            parts = line.split()
            if len(parts) >= 2:
                return int(parts[1])
        except ValueError:
            pass
    return None

def is_cloudflare(headers):
    """检查是否 Cloudflare (通过 cf-ray 头部)"""
    for line in headers:
        if line.lower().startswith("cf-ray:"):
            return True
    return False

# ---------------- 线程 worker ----------------
def worker():
    while True:
        ip = task_queue.get()
        if ip is None:  # 哨兵值
            task_queue.task_done()
            break
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
            proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout + 1)
            end = time.time()

            headers = proc.stdout.splitlines()
            status = parse_status(headers)
            cost = round((end - start) * 1000, 2)

            if proc.returncode == 0 and status in (200, 301, 403) and is_cloudflare(headers):
                with lock:
                    result_list.append((ip, cost))
                print(f"[OK] {ip} | {domain} | {status} | {cost} ms")
            else:
                error_details = proc.stderr.strip() if proc.stderr else ""
                print(f"[FAIL] {ip} | {domain} | status={status} | code={proc.returncode} | err={error_details[:50]}")

        except subprocess.TimeoutExpired:
            print(f"[TIMEOUT] {ip} | {domain} | {timeout}s")
        except Exception as e:
            print(f"[ERROR] {ip} : {e}")
        finally:
            task_queue.task_done()

# ---------------- 扫描 IP 文件 ----------------
total_ips = 0
try:
    with open(ip_file, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):  # 跳过空行和注释行
                continue
            try:
                net = ipaddress.ip_network(line, strict=False)
                for ip in net.hosts():
                    ip_str = str(ip)
                    if ip_str not in seen_ips:
                        task_queue.put(ip_str)
                        seen_ips.add(ip_str)
                        total_ips += 1
            except ValueError:
                print(f"无效 IP/段被跳过: {line}")
except FileNotFoundError:
    print(f"错误：找不到 IP 文件 {ip_file}")
    exit(1)

print(f"--- 准备扫描 {total_ips} 个 IP 地址，使用 {max_threads} 个线程 ---")

# ---------------- 启动线程 ----------------
threads = []
for _ in range(max_threads):
    t = threading.Thread(target=worker)
    t.start()
    threads.append(t)

# ---------------- 等待和优雅停止 ----------------
task_queue.join()
for _ in range(max_threads):
    task_queue.put(None)
for t in threads:
    t.join()

# ---------------- 保存结果 ----------------
result_list.sort(key=lambda x: x[1])
with open(output_file, "w") as f:
    for ip, cost in result_list:
        if output_with_latency:
            f.write(f"{ip}\t{cost}ms\n")
        else:
            f.write(f"{ip}\n")

print(f"\n✔ 扫描完成，成功找到 {len(result_list)} 个有效 Cloudflare IP，已写入：{output_file}")
