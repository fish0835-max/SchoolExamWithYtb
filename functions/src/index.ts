import * as functions from 'firebase-functions/v2/https'
import * as admin from 'firebase-admin'
import Anthropic from '@anthropic-ai/sdk'

admin.initializeApp()
const db = admin.firestore()

const SUBJECT_NAMES: Record<string, string> = {
  math: '數學',
  chinese: '國文',
}

function getAnthropicClient(): Anthropic {
  const apiKey = process.env.CLAUDE_API_KEY
  if (!apiKey) throw new Error('CLAUDE_API_KEY 未設定')
  return new Anthropic({ apiKey })
}

function parseJsonFromText(text: string): Record<string, unknown> {
  const match = text.match(/\{[\s\S]*\}/)
  if (!match) throw new Error('無法從回應中解析 JSON')
  return JSON.parse(match[0]) as Record<string, unknown>
}

// ─── generateQuestion ─────────────────────────────────────────────────────────
export const generateQuestion = functions.onCall(
  { region: 'asia-east1', secrets: ['CLAUDE_API_KEY'] },
  async (request) => {
    const {
      grade,
      subject,
      semester,
      scope_mode,
      max_unit_order,
      target_unit_order,
      unit_name,
    } = request.data as {
      grade: number
      subject: string
      semester: number
      scope_mode: 'range' | 'single'
      max_unit_order?: number
      target_unit_order?: number
      unit_name?: string
    }

    if (!grade || !subject) {
      throw new functions.HttpsError('invalid-argument', 'grade 和 subject 為必填')
    }

    const subjectName = SUBJECT_NAMES[subject] || subject
    const semesterName = semester === 1 ? '上學期' : '下學期'

    let scopeDesc = ''
    if (unit_name) {
      scopeDesc = `課次：${unit_name}`
    } else if (scope_mode === 'single' && target_unit_order) {
      scopeDesc = `第 ${target_unit_order} 課`
    } else if (scope_mode === 'range' && max_unit_order) {
      scopeDesc = `第 1 課 到 第 ${max_unit_order} 課`
    } else {
      scopeDesc = '全部課次'
    }

    const prompt = `你是台灣康軒版 ${grade} 年級${subjectName}老師。
請出一道選擇題，範圍嚴格限定在：${grade} 年級 ${semesterName} ${scopeDesc}。
不可超出 ${grade} 年級康軒課程範圍。

${subject === 'math'
    ? `數學要求：數字範圍符合該年級，四個選項需有合理干擾項`
    : `國文要求：字詞符合該年級生字表，四個選項需有合理干擾項`}

回傳格式（只回傳 JSON）：
{"question_text":"題目","options":["A","B","C","D"],"correct_answer":"正確選項","difficulty":1,"unit_name":"課次名稱"}`

    const client = getAnthropicClient()
    const response = await client.messages.create({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 512,
      messages: [{ role: 'user', content: prompt }],
    })

    const content = response.content[0]
    if (content.type !== 'text') {
      throw new functions.HttpsError('internal', 'Claude 回應格式錯誤')
    }

    const parsed = parseJsonFromText(content.text) as {
      question_text: string
      options: string[]
      correct_answer: string
      difficulty: number
      unit_name?: string
    }

    if (!parsed.options.includes(parsed.correct_answer)) {
      throw new functions.HttpsError('internal', '正確答案不在選項中')
    }

    // Cache to Firestore
    await db.collection('questions').add({
      grade,
      subject,
      semester,
      unit: parsed.unit_name || unit_name || null,
      unit_order: scope_mode === 'single' ? target_unit_order : null,
      question_text: parsed.question_text,
      options: parsed.options,
      correct_answer: parsed.correct_answer,
      question_type: 'multiple_choice',
      difficulty: parsed.difficulty || 1,
      source: 'ai',
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    })

    return {
      question_text: parsed.question_text,
      options: parsed.options,
      correct_answer: parsed.correct_answer,
      question_type: 'multiple_choice',
      difficulty: parsed.difficulty || 1,
      unit_name: parsed.unit_name || unit_name,
      source: 'ai',
    }
  }
)

// ─── generateFromPhoto ────────────────────────────────────────────────────────
export const generateFromPhoto = functions.onCall(
  { region: 'asia-east1', secrets: ['CLAUDE_API_KEY'] },
  async (request) => {
    const { image_base64, grade, subject } = request.data as {
      image_base64: string
      grade: number
      subject: string
    }

    if (!image_base64 || !grade || !subject) {
      throw new functions.HttpsError(
        'invalid-argument',
        'image_base64、grade、subject 為必填'
      )
    }

    const subjectName = SUBJECT_NAMES[subject] || subject

    const prompt = `這是台灣康軒 ${grade} 年級${subjectName}教材的照片。
請根據照片中實際呈現的內容，出一道適合 ${grade} 年級小學生的選擇題。
題目內容必須來自照片，難度符合 ${grade} 年級程度。

回傳格式（只回傳 JSON）：
{"question_text":"題目","options":["A","B","C","D"],"correct_answer":"正確選項","difficulty":1,"source_text":"出題依據"}`

    const client = getAnthropicClient()
    const response = await client.messages.create({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 512,
      messages: [
        {
          role: 'user',
          content: [
            {
              type: 'image',
              source: {
                type: 'base64',
                media_type: 'image/jpeg',
                data: image_base64,
              },
            },
            { type: 'text', text: prompt },
          ],
        },
      ],
    })

    const content = response.content[0]
    if (content.type !== 'text') {
      throw new functions.HttpsError('internal', 'Claude 回應格式錯誤')
    }

    const parsed = parseJsonFromText(content.text) as {
      question_text: string
      options: string[]
      correct_answer: string
      difficulty: number
      source_text?: string
    }

    return {
      question_text: parsed.question_text,
      options: parsed.options,
      correct_answer: parsed.correct_answer,
      question_type: 'multiple_choice',
      difficulty: parsed.difficulty || 1,
      source: 'photo',
      source_text: parsed.source_text,
    }
  }
)
