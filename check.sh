#!/usr/bin/env python3
import subprocess
import threading
import queue
import random
import ipaddress
import time

# ---------------- 配置 (可调整区域) ----------------
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
timeout = 5 # curl 命令的超时时间

# --- 验证条件 ---
CF_RAY_HEADER = "cf-ray:" # 检查 Cloudflare 存在的头部标识（小写）
SUCCESS_STATUS_CODES = (200, 301, 403) # 视为成功的 HTTP 状态码

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
        try:
            parts = line.split()
            if len(parts) >= 2:
                return int(parts[1])
        except ValueError:
            pass
    return None


def is_cloudflare(headers):
    """检查是否包含 Cloudflare 标识的头部"""
    for line in headers:
        # 使用配置中的 CF_RAY_HEADER 变量进行检查
        if line.lower().startswith(CF_RAY_HEADER):
            return True
    return False


# ---------------- 线程 worker ----------------
def worker():
    """工作线程：持续从队列中取出 IP 进行测试，直到收到 None 信号"""
    while True:
        # 阻塞式获取任务
        ip = task_queue.get()
        
        # 哨兵值：收到 None 信号，表示所有任务完成，线程退出
        if ip is None:
            task_queue.task_done()
            break
            
        domain = random.choice(domains)

        try:
            # 构建 curl 命令
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
            proc = subprocess.run(
                cmd, 
                capture_output=True, 
                text=True, 
                timeout=timeout + 1
            )
            end = time.time()

            headers = proc.stdout.splitlines()
            status = parse_status(headers)
            cost = round((end - start) * 1000, 2)
            
            # 判断成功条件：返回码为 0，状态码在配置的成功列表中，且包含 Cloudflare 标识
            if proc.returncode == 0 and status in SUCCESS_STATUS_CODES and is_cloudflare(headers):
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
            # 无论成功或失败，标记任务完成
            task_queue.task_done()


# ---------------- 扫描 IP 文件 ----------------
total_ips = 0
try:
    with open(ip_file, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                # 处理 IP 地址或 CIDR 网段
                net = ipaddress.ip_network(line, strict=False)
                for ip in net.hosts():
                    task_queue.put(str(ip))
                    total_ips += 1
            except ValueError:
                print(f"无效 IP/段被跳过: {line}")
except FileNotFoundError:
    print(f"错误：找不到 IP 文件 {ip_file}")
    exit(1)


print(f"--- 准备扫描 {total_ips} 个 IP 地址，使用 {max_threads} 个线程 ---")

# ---------------- 启动和优雅停止 ----------------
threads = []
for _ in range(max_threads):
    t = threading.Thread(target=worker)
    t.start()
    threads.append(t)

# 阻塞主线程，等待队列中的所有 IP 任务处理完毕
task_queue.join()

# 发送 None 信号 (哨兵值)，通知所有 worker 线程退出
for _ in range(max_threads):
    task_queue.put(None)

# 等待所有线程退出
for t in threads:
    t.join()


# ---------------- 保存结果 ----------------
# 按响应时间排序（最快的 Cloudflare IP 在前）
result_list.sort(key=lambda x: x[1])

with open(output_file, "w") as f:
    for ip, cost in result_list:
        # 只输出 IP
        f.write(ip + "\n")

print(f"\n=======================================================")
print(f"✔ 扫描完成，成功找到 {len(result_list)} 个有效 Cloudflare IP，已写入：{output_file}")
print(f"=======================================================")
