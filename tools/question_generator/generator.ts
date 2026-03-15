#!/usr/bin/env ts-node
/**
 * 康軒國小題庫生成工具
 * 使用 Claude API 自動生成各年級各科目的題目
 *
 * 使用方式：
 *   npx ts-node generator.ts --subject=math --grade=2 --output=json
 *   npx ts-node generator.ts --subject=math --grade=1-6 --output=sql
 *   npx ts-node generator.ts --subject=math --grade=2 --semester=1 --unit=3
 *
 * API key 讀取順序：--api-key 參數 > .env 檔案 > CLAUDE_API_KEY 環境變數
 */

import * as fs from 'fs'
import * as path from 'path'
import Anthropic from '@anthropic-ai/sdk'
import { program } from 'commander'
import { v4 as uuidv4 } from 'uuid'
import * as dotenv from 'dotenv'

// 載入 .env（API key 不進 git）
dotenv.config({ path: path.join(__dirname, '.env') })

// Types
interface CurriculumUnit {
  unit_order: number
  unit_name: string
}

interface CurriculumData {
  publisher: string
  subject: string
  grades: Record<string, Record<string, CurriculumUnit[]>>
}

interface GeneratedQuestion {
  id: string
  grade: number
  semester: number
  subject: string
  publisher: string
  unit_order: number
  unit_name: string
  question_text: string
  options: string[]
  correct_answer: string
  question_type: 'multiple_choice' | 'fill_blank'
  difficulty: 1 | 2 | 3
}

interface Config {
  claudeModel: string
  questionsPerUnit: number
  questionTypes: string[]
  difficultyDistribution: Record<string, number>
  delayBetweenRequestsMs: number
  maxRetries: number
  outputDir: string
}

interface OutputBundle {
  version: string
  subject: string
  publisher: string
  generated_at: string
  questions: GeneratedQuestion[]
}

// Load config
const config: Config = JSON.parse(
  fs.readFileSync(path.join(__dirname, 'config.json'), 'utf-8')
)

// Parse CLI arguments
program
  .name('generate-questions')
  .description('康軒國小題庫生成工具')
  .option('--subject <subject>', '科目 (math|chinese)', 'math')
  .option('--grade <grade>', '年級，可用範圍如 1-6 或單一如 2', '2')
  .option('--semester <semester>', '學期 (1|2|all)', 'all')
  .option('--unit <unit>', '課次編號（省略則生成全部課次）')
  .option('--output <format>', '輸出格式 (json|sql|both)', 'json')
  .option('--questions-per-unit <n>', '每課題目數量', String(config.questionsPerUnit))
  .option('--api-key <key>', 'Claude API key（預設從 CLAUDE_API_KEY 環境變數讀取）')
  .parse()

const options = program.opts()

// Determine grades to process
function parseGradeRange(gradeStr: string): number[] {
  if (gradeStr.includes('-')) {
    const [start, end] = gradeStr.split('-').map(Number)
    return Array.from({ length: end - start + 1 }, (_, i) => start + i)
  }
  return [parseInt(gradeStr)]
}

function parseSemesters(semesterStr: string): number[] {
  if (semesterStr === 'all') return [1, 2]
  return [parseInt(semesterStr)]
}

// Delay helper
const delay = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms))

// Generate a question using Claude API
async function generateQuestion(
  client: Anthropic,
  grade: number,
  semester: number,
  subject: string,
  unit: CurriculumUnit,
  difficulty: 1 | 2 | 3,
  questionIndex: number
): Promise<GeneratedQuestion | null> {
  const SUBJECT_NAMES: Record<string, string> = {
    math: '數學',
    chinese: '國文',
  }
  const subjectName = SUBJECT_NAMES[subject] || subject
  const semesterName = semester === 1 ? '上學期' : '下學期'

  const difficultyDesc = {
    1: '簡單（基本計算或概念確認）',
    2: '中等（需要理解或兩步驟運算）',
    3: '困難（需要綜合應用或解題策略）',
  }[difficulty]

  const prompt = `你是台灣康軒版 ${grade} 年級${subjectName}老師，正在出第 ${questionIndex + 1} 道練習題。
課次：${grade} 年級 ${semesterName} 第 ${unit.unit_order} 課「${unit.unit_name}」
難度：${difficultyDesc}

要求：
- 題目必須嚴格符合康軒 ${grade} 年級課綱，不可超出範圍
- 選項 A/B/C/D 需有合理的干擾項（常見錯誤或相近答案）
- 正確答案必須與其中一個選項完全一致
${subject === 'math' ? `- 數字範圍符合 ${grade} 年級程度
- 可以是計算題、文字應用題、或概念題` : `- 字詞範圍符合 ${grade} 年級生字表
- 可以是字音、字形、詞語理解、句子造句`}

回傳格式（只回傳 JSON，不加任何說明）：
{"question_text":"題目","options":["A","B","C","D"],"correct_answer":"正確選項","difficulty":${difficulty}}`

  for (let retry = 0; retry < config.maxRetries; retry++) {
    try {
      const response = await client.messages.create({
        model: config.claudeModel,
        max_tokens: 256,
        messages: [{ role: 'user', content: prompt }],
      })

      const content = response.content[0]
      if (content.type !== 'text') continue

      // Parse JSON
      const jsonMatch = content.text.match(/\{[\s\S]*\}/)
      if (!jsonMatch) continue

      const parsed = JSON.parse(jsonMatch[0])

      if (!parsed.question_text || !parsed.options || !parsed.correct_answer) {
        continue
      }

      // Validate correct_answer is in options
      if (!parsed.options.includes(parsed.correct_answer)) {
        // Try to fix
        const fixed = parsed.options.find((o: string) =>
          o.includes(parsed.correct_answer) ||
          parsed.correct_answer.includes(o)
        )
        if (fixed) {
          parsed.correct_answer = fixed
        } else {
          console.warn(`  ⚠ 答案不在選項中，跳過此題`)
          continue
        }
      }

      return {
        id: uuidv4(),
        grade,
        semester,
        subject,
        publisher: 'kangxuan',
        unit_order: unit.unit_order,
        unit_name: unit.unit_name,
        question_text: parsed.question_text,
        options: parsed.options,
        correct_answer: parsed.correct_answer,
        question_type: 'multiple_choice',
        difficulty: parsed.difficulty || difficulty,
      }
    } catch (err) {
      console.error(`  Retry ${retry + 1}/${config.maxRetries}: ${err}`)
      await delay(1000 * (retry + 1))
    }
  }

  return null
}

// Convert questions to SQL INSERT statements
function questionsToSql(questions: GeneratedQuestion[]): string {
  const lines = [
    '-- 康軒題庫 - 自動生成',
    `-- 生成時間：${new Date().toISOString()}`,
    '',
    'INSERT INTO questions (id, grade, subject, semester, unit, unit_order, question_text, options, correct_answer, question_type, difficulty, source) VALUES',
  ]

  const values = questions.map((q, i) => {
    const optionsJson = JSON.stringify(q.options).replace(/'/g, "''")
    const questionText = q.question_text.replace(/'/g, "''")
    const correctAnswer = q.correct_answer.replace(/'/g, "''")
    const unit = q.unit_name.replace(/'/g, "''")
    const comma = i < questions.length - 1 ? ',' : ';'
    return `  ('${q.id}', ${q.grade}, '${q.subject}', ${q.semester}, '${unit}', ${q.unit_order}, '${questionText}', '${optionsJson}'::jsonb, '${correctAnswer}', '${q.question_type}', ${q.difficulty}, 'fixed')${comma}`
  })

  return [...lines, ...values].join('\n')
}

// Main function
async function main() {
  const apiKey = options.apiKey || process.env.CLAUDE_API_KEY
  if (!apiKey) {
    console.error('❌ 請設定 CLAUDE_API_KEY 環境變數或使用 --api-key 參數')
    process.exit(1)
  }

  const subject = options.subject as string
  const grades = parseGradeRange(options.grade)
  const semesters = parseSemesters(options.semester)
  const targetUnit = options.unit ? parseInt(options.unit) : null
  const questionsPerUnit = parseInt(options.questionsPerUnit)
  const outputFormat = options.output as string

  // Load curriculum
  const curriculumFile = path.join(__dirname, 'curriculum', `${subject}_units.json`)
  if (!fs.existsSync(curriculumFile)) {
    console.error(`❌ 找不到課程檔案：${curriculumFile}`)
    process.exit(1)
  }

  const curriculum: CurriculumData = JSON.parse(
    fs.readFileSync(curriculumFile, 'utf-8')
  )

  const client = new Anthropic({ apiKey })

  const allQuestions: GeneratedQuestion[] = []

  for (const grade of grades) {
    const gradeData = curriculum.grades[String(grade)]
    if (!gradeData) {
      console.warn(`⚠ 找不到 ${grade} 年級課程資料，跳過`)
      continue
    }

    for (const semester of semesters) {
      const units = gradeData[String(semester)]
      if (!units) {
        console.warn(`⚠ 找不到 ${grade} 年級第 ${semester} 學期課程資料，跳過`)
        continue
      }

      const unitsToProcess = targetUnit
        ? units.filter((u) => u.unit_order === targetUnit)
        : units

      if (unitsToProcess.length === 0) {
        console.warn(`⚠ 找不到指定課次 ${targetUnit}`)
        continue
      }

      console.log(`\n📚 ${grade} 年級 ${semester === 1 ? '上' : '下'}學期 ${subject === 'math' ? '數學' : '國文'}`)

      for (const unit of unitsToProcess) {
        console.log(`  📖 第 ${unit.unit_order} 課「${unit.unit_name}」`)

        for (let i = 0; i < questionsPerUnit; i++) {
          // Distribute difficulty
          const diffRand = Math.random()
          let difficulty: 1 | 2 | 3 = 1
          const d = config.difficultyDistribution
          if (diffRand < d['1']) difficulty = 1
          else if (diffRand < d['1'] + d['2']) difficulty = 2
          else difficulty = 3

          process.stdout.write(`    題目 ${i + 1}/${questionsPerUnit}... `)

          const question = await generateQuestion(
            client,
            grade,
            semester,
            subject,
            unit,
            difficulty,
            i
          )

          if (question) {
            allQuestions.push(question)
            console.log('✅')
          } else {
            console.log('❌ 生成失敗')
          }

          await delay(config.delayBetweenRequestsMs)
        }
      }
    }
  }

  // Ensure output directory exists
  const outputDir = path.join(__dirname, config.outputDir)
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true })
  }

  console.log(`\n✨ 共生成 ${allQuestions.length} 道題目`)

  // Write output files
  if (outputFormat === 'json' || outputFormat === 'both') {
    const bundle: OutputBundle = {
      version: '1.0.0',
      subject,
      publisher: 'kangxuan',
      generated_at: new Date().toISOString(),
      questions: allQuestions,
    }
    const jsonPath = path.join(outputDir, 'questions.json')
    fs.writeFileSync(jsonPath, JSON.stringify(bundle, null, 2), 'utf-8')
    console.log(`📄 JSON 輸出：${jsonPath}`)
  }

  if (outputFormat === 'sql' || outputFormat === 'both') {
    const sql = questionsToSql(allQuestions)
    const sqlPath = path.join(outputDir, 'seed.sql')
    fs.writeFileSync(sqlPath, sql, 'utf-8')
    console.log(`🗄️  SQL 輸出：${sqlPath}`)
  }

  console.log('\n✅ 完成！')
}

main().catch((err) => {
  console.error('❌ 錯誤：', err)
  process.exit(1)
})
