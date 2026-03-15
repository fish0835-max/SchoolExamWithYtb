#!/usr/bin/env ts-node
/**
 * 題庫驗證工具
 * 驗證生成的題目格式是否正確
 *
 * 使用方式：
 *   npx ts-node validator.ts --file=output/questions.json
 */

import * as fs from 'fs'
import * as path from 'path'
import { program } from 'commander'

interface Question {
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
  question_type: string
  difficulty: number
}

interface ValidationResult {
  isValid: boolean
  errors: string[]
  warnings: string[]
}

program
  .name('validate-questions')
  .description('驗證題庫格式')
  .option('--file <path>', '題庫 JSON 檔案路徑', 'output/questions.json')
  .option('--grade <grade>', '只驗證指定年級')
  .option('--subject <subject>', '只驗證指定科目')
  .parse()

const options = program.opts()

function validateQuestion(q: unknown, index: number): ValidationResult {
  const errors: string[] = []
  const warnings: string[] = []

  if (!q || typeof q !== 'object') {
    return { isValid: false, errors: [`題目 ${index}: 不是有效的物件`], warnings: [] }
  }

  const question = q as Partial<Question>

  // Required fields
  if (!question.id) errors.push(`缺少 id`)
  if (!question.grade || question.grade < 1 || question.grade > 6) {
    errors.push(`grade 無效: ${question.grade}（應為 1-6）`)
  }
  if (!question.subject || !['math', 'chinese'].includes(question.subject)) {
    errors.push(`subject 無效: ${question.subject}（應為 math 或 chinese）`)
  }
  if (!question.semester || ![1, 2].includes(question.semester)) {
    errors.push(`semester 無效: ${question.semester}（應為 1 或 2）`)
  }
  if (!question.question_text || question.question_text.trim().length < 3) {
    errors.push(`question_text 太短或缺少`)
  }
  if (!question.correct_answer || question.correct_answer.trim().length === 0) {
    errors.push(`correct_answer 缺少`)
  }
  if (!question.question_type || !['multiple_choice', 'fill_blank'].includes(question.question_type)) {
    errors.push(`question_type 無效: ${question.question_type}`)
  }
  if (!question.difficulty || question.difficulty < 1 || question.difficulty > 3) {
    warnings.push(`difficulty 無效: ${question.difficulty}（應為 1-3）`)
  }

  // Multiple choice specific validation
  if (question.question_type === 'multiple_choice') {
    if (!question.options || !Array.isArray(question.options)) {
      errors.push(`multiple_choice 題目缺少 options`)
    } else if (question.options.length !== 4) {
      errors.push(`options 應有 4 個選項，實際有 ${question.options.length} 個`)
    } else {
      // Check correct_answer is in options
      if (question.correct_answer && !question.options.includes(question.correct_answer)) {
        errors.push(`correct_answer "${question.correct_answer}" 不在選項中: [${question.options.join(', ')}]`)
      }

      // Check for duplicate options
      const uniqueOptions = new Set(question.options)
      if (uniqueOptions.size !== question.options.length) {
        warnings.push(`選項中有重複項目`)
      }

      // Check options are not too similar to each other
      question.options.forEach((opt, i) => {
        if (!opt || opt.trim().length === 0) {
          errors.push(`選項 ${i + 1} 為空`)
        }
      })
    }
  }

  // Content warnings
  if (question.question_text && question.question_text.length > 200) {
    warnings.push(`題目文字過長（${question.question_text.length} 字），建議精簡`)
  }

  return {
    isValid: errors.length === 0,
    errors,
    warnings,
  }
}

function validateQuestionBank(questions: Question[], filters: { grade?: number; subject?: string }): void {
  let totalErrors = 0
  let totalWarnings = 0
  let validCount = 0

  const filtered = questions.filter((q) => {
    if (filters.grade && q.grade !== filters.grade) return false
    if (filters.subject && q.subject !== filters.subject) return false
    return true
  })

  console.log(`\n🔍 驗證 ${filtered.length} 道題目...\n`)

  filtered.forEach((q, i) => {
    const result = validateQuestion(q, i + 1)

    if (!result.isValid) {
      totalErrors += result.errors.length
      console.log(`❌ 題目 ${i + 1} (ID: ${q.id || 'unknown'})`)
      console.log(`   題目：${q.question_text?.substring(0, 50)}...`)
      result.errors.forEach((err) => console.log(`   錯誤：${err}`))
    } else {
      validCount++
    }

    if (result.warnings.length > 0) {
      totalWarnings += result.warnings.length
      if (result.isValid) {
        console.log(`⚠ 題目 ${i + 1}：${q.question_text?.substring(0, 40)}...`)
      }
      result.warnings.forEach((w) => console.log(`  警告：${w}`))
    }
  })

  // Statistics
  console.log('\n📊 驗證結果統計：')
  console.log(`  ✅ 有效題目：${validCount}/${filtered.length}`)
  console.log(`  ❌ 錯誤：${totalErrors}`)
  console.log(`  ⚠ 警告：${totalWarnings}`)

  // Grade/subject distribution
  const stats: Record<string, Record<string, number>> = {}
  filtered.forEach((q) => {
    const key = `${q.grade}年級`
    if (!stats[key]) stats[key] = {}
    const subjKey = q.subject === 'math' ? '數學' : '國文'
    stats[key][subjKey] = (stats[key][subjKey] || 0) + 1
  })

  console.log('\n📚 年級/科目分布：')
  Object.entries(stats)
    .sort()
    .forEach(([grade, subjects]) => {
      console.log(`  ${grade}：${Object.entries(subjects).map(([s, c]) => `${s} ${c} 題`).join('、')}`)
    })

  if (totalErrors > 0) {
    console.log('\n❌ 驗證失敗，請修正上述錯誤')
    process.exit(1)
  } else {
    console.log('\n✅ 所有題目格式正確！')
  }
}

// Main
const filePath = path.resolve(options.file)
if (!fs.existsSync(filePath)) {
  console.error(`❌ 找不到檔案：${filePath}`)
  process.exit(1)
}

const raw = JSON.parse(fs.readFileSync(filePath, 'utf-8'))
const questions: Question[] = raw.questions || raw

const filters: { grade?: number; subject?: string } = {}
if (options.grade) filters.grade = parseInt(options.grade)
if (options.subject) filters.subject = options.subject

validateQuestionBank(questions, filters)
