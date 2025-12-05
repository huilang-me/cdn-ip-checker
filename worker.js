const VERIFY_PATH = '/uuid' // 请求验证路径
const IP_LIST_URL = 'https://xxx/valid_ips.txt' // 你自己的IP 列表 URL
const proxies = [
  'vless://path@ip:443?encryption=none&security=tls&type=ws&host=host&path=%2F23path',
  'trojan://path@ip:443?encryption=none&security=tls&type=ws&host=host&path=%2F23path'
]

addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request))
})

/**
 * 处理请求
 * @param {Request} request
 */
async function handleRequest(request) {
  const url = new URL(request.url)

  if (url.pathname !== VERIFY_PATH) {
    return new Response('Not Found', { status: 404 })
  }

  const id = parseInt(url.searchParams.get('id')) || 0

  if (id < 0 || id >= proxies.length) {
    return new Response('Invalid id', { status: 400 })
  }
  const selectedProxy = proxies[id]

  try {
    // 生成带时间戳的 URL
    const timestamp = Date.now()
    const fetchUrl = `${IP_LIST_URL}?t=${timestamp}`

    const resp = await fetch(fetchUrl)
    if (!resp.ok) throw new Error('Failed to fetch IP list')
    const ipText = await resp.text()
    const ips = ipText.split(/\r?\n/).filter(line => line.trim())

    // 替换 IP 并在末尾追加 #ip
    const allProxiesText = ips.map(ip => {
      // 去掉原来的 # 后缀
      let proxy = selectedProxy.replace(/#.*$/, '')
      // 替换 IP
      proxy = proxy.replace(/@.*?:443/, `@${ip}:443`)
      // 追加 #ip
      return `${proxy}#${ip}`
    }).join('\n')


    // 整个文本 base64
    const base64Text = btoa(allProxiesText)

    return new Response(base64Text, {
      headers: { 'Content-Type': 'text/plain;charset=UTF-8' }
    })

  } catch (err) {
    return new Response(err.message, { status: 500 })
  }
}
