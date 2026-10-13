// Картинки-превью стадиона: собирает стадион в имитации и рисует его через three.js.
// Запуск: node test/render/render.mjs [виды через запятую] [day|night]
import { LuauState } from 'luau-web'
import fs from 'fs'
import path from 'path'
import http from 'http'
import { execFile } from 'child_process'
import { fileURLToPath } from 'url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..')
const outDir = path.join(root, 'build', 'preview')
fs.mkdirSync(outDir, { recursive: true })
for (const stream of [process.stdout, process.stderr]) {
  const write = stream.write.bind(stream)
  stream.write = (chunk, ...rest) => {
    const text = String(chunk).replace(/(1: \(null\), tag: -1)+/g, '')
    if (text.includes('[luau-interop]')) return true
    return text ? write(text, ...rest) : true
  }
}

// 1. Выгружаем сцену
const files = {}
const walk = (d) => fs.readdirSync(d, { withFileTypes: true }).forEach((e) => {
  const f = path.join(d, e.name)
  if (e.isDirectory()) walk(f)
  else if (e.name.endsWith('.luau')) files[path.relative(root, f).split(path.sep).join('/')] = fs.readFileSync(f, 'utf8')
})
walk(path.join(root, 'src'))
let state
state = await LuauState.createAsync({
  compile: (src, name) => state.loadstring(src, name, false),
  readSource: (p) => files[p] ?? fs.readFileSync(path.join(root, p), 'utf8'),
  listSources: () => Object.keys(files).join('\n'),
  writeOutput: (s) => fs.writeFileSync(path.join(outDir, 'scene.json'), s),
})
await state.loadstring(fs.readFileSync(path.join(root, 'test/sim/DumpScene.luau'), 'utf8'), 'DumpScene', true)()

// 2. Рисуем
const server = http.createServer((req, res) => {
  const p = path.join(root, decodeURIComponent(new URL(req.url, 'http://x').pathname))
  if (!p.startsWith(root) || !fs.existsSync(p)) { res.writeHead(404); return res.end() }
  const type = p.endsWith('.html') ? 'text/html' : p.endsWith('.js') ? 'text/javascript' : 'application/json'
  res.writeHead(200, { 'Content-Type': type }); fs.createReadStream(p).pipe(res)
}).listen(0)
const port = server.address().port
const views = (process.argv[2] || 'aerial,broadcast,goal,pitch,stand,tunnel,dressing,lobby,jail,outside').split(',')
const mode = process.argv[3] || 'night'
const chrome = '/opt/pw-browsers/chromium-1194/chrome-linux/chrome'
for (const view of views) {
  const file = path.join(outDir, `${view}-${mode}.png`)
  // Асинхронно: пока браузер грузит страницу, наш сервер должен отвечать
  await new Promise((resolve) => {
    execFile(chrome, ['--headless=new', '--no-sandbox', '--use-angle=swiftshader', '--enable-unsafe-swiftshader',
      '--hide-scrollbars', '--window-size=1280,808', '--virtual-time-budget=60000',
      `--screenshot=${file}`, `http://127.0.0.1:${port}/test/render/viewer.html?view=${view}&mode=${mode}`],
    { timeout: 300000 }, (err) => { if (err) console.log('не получилось:', view, err.message); resolve() })
  })
  console.log('готово:', path.relative(root, file))
}
server.close()
