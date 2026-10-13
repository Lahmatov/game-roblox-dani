// Запускает автоматический плейтест игры в Luau (без Roblox Studio).
// Установка: npm install   Запуск: npm test
import { LuauState } from 'luau-web'
import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')

function listLuau(dir) {
  const out = []
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name)
    if (entry.isDirectory()) out.push(...listLuau(full))
    else if (entry.name.endsWith('.luau')) out.push(full)
  }
  return out
}

// Убираем служебный шум, который печатает сам luau-web
for (const stream of [process.stdout, process.stderr]) {
  const write = stream.write.bind(stream)
  stream.write = (chunk, ...rest) => {
    const text = String(chunk).replace(/(1: \(null\), tag: -1)+/g, '')
    if (text.includes('[luau-interop]')) return true
    return text ? write(text, ...rest) : true
  }
}

let state
const files = {}
const compile = (src, name) => state.loadstring(src, name, false)
const readSource = (p) => files[p] ?? fs.readFileSync(path.join(root, p), 'utf8')
const listSources = () => Object.keys(files).join('\n')
state = await LuauState.createAsync({ compile, readSource, listSources })

// 1. Все файлы игры должны компилироваться
let compileErrors = 0
for (const file of listLuau(path.join(root, 'src'))) {
  const rel = path.relative(root, file).split(path.sep).join('/')
  const src = fs.readFileSync(file, 'utf8')
  const result = compile(src, rel)
  if (typeof result === 'string') {
    console.log('Ошибка компиляции:', rel, result)
    compileErrors++
  }
  files[rel] = src
}
if (compileErrors) process.exit(1)
console.log(`Компиляция: ${Object.keys(files).length} файлов, ошибок нет`)

// 2. Плейтест
const playtest = state.loadstring(readSource('test/sim/Playtest.luau'), 'Playtest', true)
let failed = await playtest()
if (Array.isArray(failed)) failed = failed[0]
process.exit(failed === 0 ? 0 : 1)
