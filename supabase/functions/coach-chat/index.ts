// FuelWindow Edge Function: coach-chat
// Deploy: supabase functions deploy coach-chat --no-verify-jwt
//
// Request  POST /functions/v1/coach-chat
// Requires Edge Function secret: GEMINI_API_KEY
// Body: { metrics: object, messages: [{ role: "user" | "assistant", content: string }] }
// Response: { "reply": string }

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
    const { metrics, messages } = await req.json();
    if (!metrics || !Array.isArray(messages) || messages.length === 0) {
      return jsonResponse(
        { error: "metrics and at least one message are required" },
        400,
      );
    }

    const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? Deno.env.get("GOOGLE_API_KEY");
    if (!geminiKey) {
      return jsonResponse({ error: "GEMINI_API_KEY secret not set" }, 500);
    }

    const prompt = buildPrompt(metrics, messages);
    const response = await fetch(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent",
      {
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
            temperature: 0.35,
            maxOutputTokens: 900,
            thinkingConfig: {
              thinkingBudget: 0,
            },
          },
        }),
      },
    );

    const aiResult = await response.json();
    if (!response.ok) {
      const detail = aiResult.error?.message ?? aiResult;
      if (response.status === 400 && String(detail).toLowerCase().includes("api key")) {
        return jsonResponse(
          {
            error: "Gemini API key is invalid",
            detail:
              "Check the Supabase Edge Function secret named GEMINI_API_KEY. It must be a Google AI Studio/Gemini API key, not the Supabase anon key or an OpenAI key.",
          },
          502,
        );
      }

      return jsonResponse(
        {
          error: "Gemini request failed",
          status: response.status,
          detail,
        },
        502,
      );
    }

    const reply = aiResult.candidates?.[0]?.content?.parts
      ?.map((part: { text?: string }) => part.text ?? "")
      .join("")
      .trim() ?? "";

    if (!reply) {
      return jsonResponse({ error: "Gemini returned an empty response" }, 502);
    }

    return jsonResponse({ reply });
  } catch (err) {
    return jsonResponse({ error: String(err) }, 500);
  }
});

function buildPrompt(metrics: unknown, messages: unknown[]): string {
  const safeMetrics = JSON.stringify(metrics, null, 2).slice(0, 12000);
  const conversation = messages
    .slice(-10)
    .map((message) => {
      const item = message as { role?: string; content?: string };
      const role = item.role === "assistant" ? "assistant" : "user";
      const content = String(item.content ?? "").slice(0, 1200);
      return `${role}: ${content}`;
    })
    .join("\n\n");

  return `You are FuelWindow's athletic fueling coach.

Use the user's recent metrics to give practical nutrition, recovery, and workout-timing advice.
Prioritize glycogen readiness, macro timing, hydration/electrolytes when relevant, and the next planned training session.
Always account for the user's workout split details, active food/fueling plan, and full stats summary when provided.
Use the user's allergies and GLP-1 status if provided.
Do not diagnose disease, prescribe medication, or give emergency guidance. If the user asks for medical advice, tell them to talk with a qualified clinician.
Be concise, specific, and actionable. Prefer 3-6 short bullets or short paragraphs. Use grams and timing windows when the metrics support them.

Recent metrics JSON:
${safeMetrics}

Conversation:
${conversation}

Answer the latest user message.`;
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
