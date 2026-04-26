// FuelWindow Edge Function: food-parser
// Deploy: supabase functions deploy food-parser --no-verify-jwt
//
// Request  POST /functions/v1/food-parser
// Requires Edge Function secret: GEMINI_API_KEY
// Body: { "description"?: string, "image_base64"?: string, "mime_type"?: string }
//
// Response:
// {
//   "food_name": string,
//   "grams": number,
//   "carbs_g": number,
//   "glucose_g": number,
//   "fructose_g": number,
//   "fiber_g": number,
//   "protein_g": number,
//   "fat_g": number,
//   "calories": number,
//   "micros": {
//     "magnesium_mg": number,
//     "potassium_mg": number,
//     "sodium_mg": number,
//     "iron_mg": number,
//     "zinc_mg": number,
//     "b12_mcg": number,
//     "vitamin_d_iu": number
//   },
//   "is_high_fat": boolean,
//   "is_high_fiber": boolean
// }

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const maxImageBytes = 8 * 1024 * 1024;
const supportedImageMimeTypes = new Set([
  "image/png",
  "image/jpeg",
  "image/webp",
  "image/heic",
  "image/heif",
]);

const nutritionSchema = {
  type: "object",
  properties: {
    food_name: { type: "string" },
    grams: { type: "number" },
    carbs_g: { type: "number" },
    glucose_g: { type: "number" },
    fructose_g: { type: "number" },
    fiber_g: { type: "number" },
    protein_g: { type: "number" },
    fat_g: { type: "number" },
    calories: { type: "number" },
    micros: {
      type: "object",
      properties: {
        magnesium_mg: { type: "number" },
        potassium_mg: { type: "number" },
        sodium_mg: { type: "number" },
        iron_mg: { type: "number" },
        zinc_mg: { type: "number" },
        b12_mcg: { type: "number" },
        vitamin_d_iu: { type: "number" },
      },
      required: [
        "magnesium_mg",
        "potassium_mg",
        "sodium_mg",
        "iron_mg",
        "zinc_mg",
        "b12_mcg",
        "vitamin_d_iu",
      ],
    },
    is_high_fat: { type: "boolean" },
    is_high_fiber: { type: "boolean" },
  },
  required: [
    "food_name",
    "grams",
    "carbs_g",
    "glucose_g",
    "fructose_g",
    "fiber_g",
    "protein_g",
    "fat_g",
    "calories",
    "micros",
    "is_high_fat",
    "is_high_fiber",
  ],
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    let body: {
      description?: unknown;
      image_base64?: unknown;
      mime_type?: unknown;
    };
    try {
      body = await req.json();
    } catch {
      return jsonResponse({ error: "valid JSON body required" }, 400);
    }

    const description = typeof body.description === "string"
      ? body.description.trim()
      : "";
    const imageBase64Raw = typeof body.image_base64 === "string"
      ? body.image_base64.trim()
      : "";
    let mimeType = typeof body.mime_type === "string"
      ? body.mime_type.trim().toLowerCase()
      : "";

    if (!description && !imageBase64Raw) {
      return jsonResponse({ error: "description or image_base64 required" }, 400);
    }

    let imageBase64 = "";
    if (imageBase64Raw) {
      const normalized = normalizeImageBase64(imageBase64Raw);
      imageBase64 = normalized.base64;
      mimeType = mimeType || normalized.mimeType;
      mimeType = normalizeMimeType(mimeType);

      if (!mimeType || !mimeType.startsWith("image/")) {
        return jsonResponse({ error: "mime_type must be an image MIME type" }, 400);
      }
      if (!supportedImageMimeTypes.has(mimeType)) {
        return jsonResponse({
          error: "unsupported image type",
          detail: "Use JPEG, PNG, WEBP, HEIC, or HEIF.",
        }, 415);
      }
      if (!isBase64(imageBase64)) {
        return jsonResponse({ error: "image_base64 must be valid base64 image data" }, 400);
      }
      if (base64ByteLength(imageBase64) > maxImageBytes) {
        return jsonResponse({ error: "image is too large; use an image under 8 MB" }, 413);
      }
    }

    const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? Deno.env.get("GOOGLE_API_KEY");
    if (!geminiKey) {
      return jsonResponse({ error: "GEMINI_API_KEY secret not set" }, 500);
    }

    const prompt = imageBase64
      ? `Read this packaged food nutrition facts label and estimate nutrition for the labeled serving.
Return a single JSON object matching the configured schema. Use numbers, not strings.

${description ? `Additional description: ${description}` : ""}

Set food_name to the product or serving name if visible. Estimate missing glucose/fructose split from total carbohydrates and sugar context when the label does not provide it.`
      : `Estimate nutrition for this food description.
Return a single JSON object matching the configured schema. Use numbers, not strings.

Food description: ${description}

Be as accurate as possible using USDA FoodData Central values. If multiple foods are described, aggregate them.`;

    const parts: Array<Record<string, unknown>> = [{ text: prompt }];
    if (imageBase64) {
      parts.push({
        inline_data: {
          mime_type: mimeType,
          data: imageBase64,
        },
      });
    }

    const response = await fetch("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": geminiKey,
      },
      body: JSON.stringify({
        contents: [
          {
            role: "user",
            parts,
          },
        ],
        generationConfig: {
          temperature: 0.1,
          maxOutputTokens: 1200,
          responseMimeType: "application/json",
          responseSchema: nutritionSchema,
          thinkingConfig: {
            thinkingBudget: 0,
          },
        },
      }),
    });

    const aiResult = await response.json();
    if (!response.ok) {
      const detail = aiResult.error?.message ?? aiResult;
      if (response.status === 400 && String(detail).toLowerCase().includes("api key")) {
        return jsonResponse({
          error: "Gemini API key is invalid",
          detail:
            "Check the Supabase Edge Function secret named GEMINI_API_KEY. It must be a Google AI Studio/Gemini API key, not the Supabase anon key or an OpenAI key.",
        }, 502);
      }

      return jsonResponse({
        error: "Gemini request failed",
        status: response.status,
        detail,
      }, 502);
    }

    const content = aiResult.candidates?.[0]?.content?.parts
      ?.map((part: { text?: string }) => part.text ?? "")
      .join("") ?? "";
    if (!content.trim()) {
      return jsonResponse({ error: "Gemini returned an empty response" }, 502);
    }

    let parsed;
    try {
      parsed = JSON.parse(extractJson(content));
    } catch (err) {
      return jsonResponse({
        error: "Gemini returned invalid JSON",
        detail: String(err),
        raw_preview: content.slice(0, 300),
      }, 502);
    }

    return jsonResponse(parsed);
  } catch (err) {
    return jsonResponse({ error: String(err) }, 500);
  }
});

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function normalizeImageBase64(raw: string): { base64: string; mimeType: string } {
  const dataUrl = raw.match(/^data:(image\/[-+.\w]+);base64,(.+)$/is);
  if (dataUrl) {
    return {
      mimeType: dataUrl[1].toLowerCase(),
      base64: dataUrl[2].replace(/\s/g, ""),
    };
  }

  return { mimeType: "", base64: raw.replace(/\s/g, "") };
}

function normalizeMimeType(mimeType: string): string {
  const normalized = mimeType.trim().toLowerCase();
  return normalized === "image/jpg" ? "image/jpeg" : normalized;
}

function isBase64(value: string): boolean {
  if (!value || value.length % 4 === 1) return false;
  return /^[A-Za-z0-9+/]*={0,2}$/.test(value);
}

function base64ByteLength(value: string): number {
  const padding = value.endsWith("==") ? 2 : value.endsWith("=") ? 1 : 0;
  return Math.floor((value.length * 3) / 4) - padding;
}

function extractJson(content: string): string {
  const trimmed = content.trim();
  const fenced = trimmed.match(/^```(?:json)?\s*([\s\S]*?)\s*```$/i);
  if (fenced) return fenced[1].trim();

  const start = trimmed.indexOf("{");
  const end = trimmed.lastIndexOf("}");
  if (start >= 0 && end > start) {
    return trimmed.slice(start, end + 1);
  }

  return trimmed;
}
