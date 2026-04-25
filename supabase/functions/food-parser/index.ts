// FuelWindow Edge Function: food-parser
// Deploy: supabase functions deploy food-parser --no-verify-jwt
//
// Request  POST /functions/v1/food-parser
// Requires Edge Function secret: OPENAI_API_KEY
// The secret value is treated as a Gemini API key.
// Body: { "description": string, "image_url"?: string }
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
    const { description, image_url } = await req.json();

    if (!description && !image_url) {
      return new Response(
        JSON.stringify({ error: "description or image_url required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const geminiKey = Deno.env.get("OPENAI_API_KEY") ?? Deno.env.get("OPEN_AI_KEY");
    if (!geminiKey) {
      return new Response(
        JSON.stringify({ error: "Gemini API key secret not set" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const prompt = `Estimate nutrition for this food description.
Return a single JSON object matching the configured schema. Use numbers, not strings.

Food description: ${description}
${image_url ? `Image URL: ${image_url}` : ""}

Be as accurate as possible using USDA FoodData Central values. If multiple foods are described, aggregate them.`;

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
            parts: [{ text: prompt }],
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
      return new Response(
        JSON.stringify({
          error: "Gemini request failed",
          status: response.status,
          detail: aiResult.error?.message ?? aiResult,
        }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const content = aiResult.candidates?.[0]?.content?.parts
      ?.map((part: { text?: string }) => part.text ?? "")
      .join("") ?? "";
    if (!content.trim()) {
      return new Response(
        JSON.stringify({ error: "Gemini returned an empty response" }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    let parsed;
    try {
      parsed = JSON.parse(extractJson(content));
    } catch (err) {
      return new Response(
        JSON.stringify({
          error: "Gemini returned invalid JSON",
          detail: String(err),
          raw_preview: content.slice(0, 300),
        }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(JSON.stringify(parsed), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

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
