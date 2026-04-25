// FuelWindow Edge Function: food-parser
// Deploy: supabase functions deploy food-parser --no-verify-jwt
//
// Request  POST /functions/v1/food-parser
// Requires Edge Function secret: OPENAI_API_KEY
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

    const openAiKey = Deno.env.get("OPENAI_API_KEY");
    if (!openAiKey) {
      return new Response(
        JSON.stringify({ error: "OPENAI_API_KEY not set" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const prompt = `You are a precise nutrition database. Parse this food description and return ONLY valid JSON with these exact fields (no extra text):
{
  "food_name": "descriptive name",
  "grams": <serving weight in grams>,
  "carbs_g": <total carbohydrates>,
  "glucose_g": <glucose/starch portion of carbs>,
  "fructose_g": <fructose portion of carbs>,
  "fiber_g": <dietary fiber>,
  "protein_g": <protein>,
  "fat_g": <fat>,
  "calories": <kcal>,
  "micros": {
    "magnesium_mg": <number>,
    "potassium_mg": <number>,
    "sodium_mg": <number>,
    "iron_mg": <number>,
    "zinc_mg": <number>,
    "b12_mcg": <number>,
    "vitamin_d_iu": <number>
  },
  "is_high_fat": <true if fat_g > 15>,
  "is_high_fiber": <true if fiber_g > 5>
}

Food description: "${description}"
${image_url ? `Image URL: ${image_url}` : ""}

Be as accurate as possible using USDA FoodData Central values. If multiple foods are described, aggregate them.`;

    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${openAiKey}`,
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: [{ role: "user", content: prompt }],
        temperature: 0.1,
        max_tokens: 500,
        response_format: { type: "json_object" },
      }),
    });

    const aiResult = await response.json();
    if (!response.ok) {
      return new Response(
        JSON.stringify({
          error: "OpenAI request failed",
          status: response.status,
          detail: aiResult.error?.message ?? aiResult,
        }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const content = aiResult.choices?.[0]?.message?.content ?? "";
    if (!content.trim()) {
      return new Response(
        JSON.stringify({ error: "OpenAI returned an empty response" }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Strip markdown code fences if present
    const cleaned = content.replace(/^```json\n?/, "").replace(/\n?```$/, "").trim();
    const parsed = JSON.parse(cleaned);

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
