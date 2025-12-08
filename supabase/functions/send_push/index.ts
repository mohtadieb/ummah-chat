// supabase/functions/send_push/index.ts

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

serve(async (req: Request) => {
  try {
    const body = await req.json();

    const {
      fcm_token,
      title,
      body: messageBody,
      data,
    } = body;

    if (!fcm_token) {
      return new Response(
        JSON.stringify({ error: "Missing fcm_token" }),
        { status: 400 },
      );
    }

    const payload = {
      message: {
        token: fcm_token,
        notification: {
          title: title ?? "New notification",
          body: messageBody ?? "",
        },
        data: data ?? {},
      },
    };

    // ✅ Use your REAL Firebase project ID here
    const projectId = Deno.env.get("FIREBASE_PROJECT_ID") ?? "ummah-chat-e8a4e";

    const firebaseRes = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${await getAccessToken()}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(payload),
      },
    );

    const json = await firebaseRes.json();

    return new Response(JSON.stringify(json), {
      headers: { "Content-Type": "application/json" },
      status: firebaseRes.status,
    });
  } catch (err) {
    console.error(err);
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500 },
    );
  }
});

// 🔐 Helper: Get OAuth token from Firebase service account stored in Supabase secrets
async function getAccessToken(): Promise<string> {
  const rawPrivateKey = Deno.env.get("FIREBASE_PRIVATE_KEY");
  const clientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL");
  const projectId = Deno.env.get("FIREBASE_PROJECT_ID");

  if (!rawPrivateKey || !clientEmail || !projectId) {
    throw new Error("Missing Firebase secrets");
  }

  // 1) Normalize PEM: handle both "\n" style and real newlines
  let pem = rawPrivateKey.trim();

  // If the key came from JSON, it will contain literal "\n" sequences
  if (pem.includes("\\n")) {
    pem = pem.replace(/\\n/g, "\n");
  }

  // Strip header/footer
  pem = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .trim();

  // Remove all real newlines and whitespace → pure base64
  const base64Key = pem.replace(/\r?\n/g, "").replace(/\s+/g, "");

  // Safety check: base64 length must be > 0
  if (!base64Key) {
    throw new Error("Empty private key after cleaning");
  }

  // 2) Decode base64 → binary DER
  let binaryDer: Uint8Array;
  try {
    const binaryDerString = atob(base64Key);
    binaryDer = new Uint8Array(
      [...binaryDerString].map((c) => c.charCodeAt(0)),
    );
  } catch (e) {
    console.error("❌ Failed to decode base64 private key:", e);
    throw new Error("Failed to decode base64");
  }

  // 3) Import as PKCS8 key
  const key = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer.buffer,
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"],
  );

  const jwtHeader = { alg: "RS256", typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const jwtClaimSet = {
    iss: clientEmail,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };

  function base64url(input: string) {
    return btoa(input)
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");
  }

  const headerPart = base64url(JSON.stringify(jwtHeader));
  const payloadPart = base64url(JSON.stringify(jwtClaimSet));
  const dataToSign = `${headerPart}.${payloadPart}`;

  const encoder = new TextEncoder();
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    encoder.encode(dataToSign),
  );

  const signatureStr = String.fromCharCode(...new Uint8Array(signature));
  const signaturePart = base64url(signatureStr);

  const signedJwt = `${dataToSign}.${signaturePart}`;

  // 4) Exchange JWT for access token
  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: signedJwt,
    }),
  });

  const tokenJson = await tokenRes.json();

  if (tokenJson.error) {
    console.error("Token error:", tokenJson);
    throw new Error(JSON.stringify(tokenJson));
  }

  return tokenJson.access_token as string;
}
