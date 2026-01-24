// supabase/functions/send_push/index.ts

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// -------------------------
// Helpers
// -------------------------

type NotifType =
  | "FOLLOW_USER"
  | "FRIEND_REQUEST"
  | "FRIEND_ACCEPTED"
  | "MAHRAM_REQUEST"
  | "MAHRAM_ACCEPTED"
  | "LIKE_POST"
  | "COMMENT_POST"
  | "COMMENT_REPLY"
  | "CHAT_MESSAGE"
  | "GROUP_MESSAGE"
  | "GROUP_ADDED"
  | "COMMUNITY_INVITE"
  | "MARRIAGE_INQUIRY_REQUEST"
  | "MARRIAGE_INQUIRY_MAHRAM"
  | "MARRIAGE_INQUIRY_MAN_DECISION"
  | "MARRIAGE_INQUIRY_MAHRAM_ACCEPTED"
  | "MARRIAGE_INQUIRY_MAHRAM_ACCEPTED_SENT_TO"
  | "MARRIAGE_INQUIRY_ACCEPTED"
  | "MARRIAGE_INQUIRY_DECLINED"
  | "MARRIAGE_INQUIRY_GROUP_CREATED";

type LocaleCode = "en" | "nl" | "ar";

function normalizeLocale(input: unknown): LocaleCode {
  const s = String(input ?? "").toLowerCase().trim();
  if (s.startsWith("nl")) return "nl";
  if (s.startsWith("ar")) return "ar";
  return "en";
}

function safeStr(v: unknown): string {
  return String(v ?? "").trim();
}

function toStringMap(obj: unknown): Record<string, string> {
  const out: Record<string, string> = {};
  if (!obj || typeof obj !== "object") return out;

  for (const [k, v] of Object.entries(obj as Record<string, unknown>)) {
    out[k] = String(v ?? "");
  }
  return out;
}

function pickFirstName(fullName: string): string {
  const name = fullName.trim();
  if (!name) return "";
  return name.split(/\s+/)[0] ?? name;
}

function template(
  locale: LocaleCode,
  type: NotifType,
  args: Record<string, string>,
): { title: string; body: string } {
  const senderName = safeStr(args.senderName);
  const senderFirst = pickFirstName(senderName);
  const groupName = safeStr(args.groupName);
  const preview = safeStr(args.preview);

  // ✅ optional "name" arg for templates like: "sent to {name}"
  const nameArg = safeStr(args.name);

  if (locale === "nl") {
    switch (type) {
      case "FOLLOW_USER":
        return {
          title: "Nieuwe volger",
          body: senderFirst ? `${senderFirst} volgt je nu.` : "Iemand volgt je nu.",
        };

      case "FRIEND_REQUEST":
        return {
          title: "Vriendschapsverzoek",
          body: senderFirst
            ? `${senderFirst} heeft je een vriendschapsverzoek gestuurd.`
            : "Je hebt een vriendschapsverzoek ontvangen.",
        };

      case "FRIEND_ACCEPTED":
        return {
          title: "Vriendschap geaccepteerd",
          body: senderFirst
            ? `${senderFirst} accepteerde je vriendschapsverzoek.`
            : "Je vriendschapsverzoek is geaccepteerd.",
        };

      case "MAHRAM_REQUEST":
        return {
          title: "Mahram-verzoek",
          body: senderFirst
            ? `${senderFirst} heeft je een mahram-verzoek gestuurd.`
            : "Je hebt een mahram-verzoek ontvangen.",
        };

      case "MAHRAM_ACCEPTED":
        return {
          title: "Mahram geaccepteerd",
          body: senderFirst
            ? `${senderFirst} accepteerde je mahram-verzoek.`
            : "Je mahram-verzoek is geaccepteerd.",
        };

      case "LIKE_POST":
        return {
          title: "Nieuwe like",
          body: preview
            ? `“${preview}”`
            : senderFirst
              ? `${senderFirst} vond je bericht leuk.`
              : "Iemand vond je bericht leuk.",
        };

      case "COMMENT_POST":
        return {
          title: "Nieuwe reactie",
          body: preview
            ? `“${preview}”`
            : senderFirst
              ? `${senderFirst} reageerde op je bericht.`
              : "Iemand reageerde op je bericht.",
        };

      case "COMMENT_REPLY":
        return {
          title: "Reactie op je reactie",
          body: preview
            ? `“${preview}”`
            : senderFirst
              ? `${senderFirst} reageerde op jouw reactie.`
              : "Iemand reageerde op jouw reactie.",
        };

      case "CHAT_MESSAGE":
        return {
          title: senderFirst || "Nieuw bericht",
          body: preview || "Je hebt een nieuw bericht ontvangen.",
        };

      case "GROUP_MESSAGE":
        return {
          title: groupName || "Groepsbericht",
          body:
            preview ||
            (groupName ? `Nieuw bericht in ${groupName}.` : "Nieuw groepsbericht."),
        };

      case "GROUP_ADDED":
        return {
          title: groupName || "Groep",
          body: senderFirst
            ? `${senderFirst} heeft je toegevoegd aan de groep.`
            : "Je bent toegevoegd aan een groep.",
        };
      case "COMMUNITY_INVITE":
        return {
          title: "Community-uitnodiging",
          body: nameArg
            ? `Je bent uitgenodigd voor ${nameArg}.`
            : "Je hebt een community-uitnodiging ontvangen.",
        };
      // -------------------------
      // 💍 Marriage inquiry (NL)
      // -------------------------
      case "MARRIAGE_INQUIRY_REQUEST":
        return {
          title: "Huwelijksaanvraag",
          body: senderFirst
            ? `${senderFirst} heeft een huwelijksaanvraag gestuurd. Tik om te bekijken.`
            : "Je hebt een huwelijksaanvraag ontvangen.",
        };

      case "MARRIAGE_INQUIRY_MAHRAM":
        return {
          title: "Mahram gekozen",
          body: senderFirst
            ? `${senderFirst} heeft jou gekozen als mahram voor een huwelijksaanvraag. Tik om het profiel te bekijken.`
            : "Je bent gekozen als mahram voor een huwelijksaanvraag.",
        };

      case "MARRIAGE_INQUIRY_MAN_DECISION":
        return {
          title: "Beslissing nodig",
          body: senderFirst
            ? `${senderFirst} heeft een huwelijksaanvraag gedaan. Tik om te accepteren of te weigeren.`
            : "Er is een huwelijksaanvraag. Tik om te accepteren of te weigeren.",
        };

      case "MARRIAGE_INQUIRY_MAHRAM_ACCEPTED":
        return {
          title: "Mahram geaccepteerd",
          body: "De mahram heeft de huwelijksaanvraag geaccepteerd.",
        };

      case "MARRIAGE_INQUIRY_MAHRAM_ACCEPTED_SENT_TO":
        return {
          title: "Mahram geaccepteerd",
          body: nameArg
            ? `De mahram heeft de huwelijksaanvraag geaccepteerd, aanvraag verzonden naar ${nameArg}.`
            : "De mahram heeft de huwelijksaanvraag geaccepteerd, aanvraag is verzonden.",
        };


      case "MARRIAGE_INQUIRY_ACCEPTED":
        return {
          title: "Huwelijksaanvraag geaccepteerd",
          body: senderFirst
            ? `${senderFirst} heeft de huwelijksaanvraag geaccepteerd.`
            : "De huwelijksaanvraag is geaccepteerd.",
        };

      case "MARRIAGE_INQUIRY_DECLINED":
        return {
          title: "Huwelijksaanvraag geweigerd",
          body: senderFirst
            ? `${senderFirst} heeft de huwelijksaanvraag geweigerd.`
            : "De huwelijksaanvraag is geweigerd.",
        };

      case "MARRIAGE_INQUIRY_GROUP_CREATED":
        return {
          title: "Groep aangemaakt",
          body: "De groepschat voor de huwelijksaanvraag is aangemaakt. Tik om te openen.",
        };
    }
  }

  if (locale === "ar") {
    switch (type) {
      case "FOLLOW_USER":
        return {
          title: "متابع جديد",
          body: senderFirst ? `${senderFirst} بدأ بمتابعتك.` : "بدأ شخص ما بمتابعتك.",
        };

      case "FRIEND_REQUEST":
        return {
          title: "طلب صداقة",
          body: senderFirst ? `${senderFirst} أرسل لك طلب صداقة.` : "لديك طلب صداقة جديد.",
        };

      case "FRIEND_ACCEPTED":
        return {
          title: "تم قبول طلب الصداقة",
          body: senderFirst ? `${senderFirst} قبل طلب صداقتك.` : "تم قبول طلب صداقتك.",
        };

      case "MAHRAM_REQUEST":
        return {
          title: "طلب محرم",
          body: senderFirst ? `${senderFirst} أرسل لك طلب محرم.` : "لديك طلب محرم جديد.",
        };

      case "MAHRAM_ACCEPTED":
        return {
          title: "تم قبول طلب المحرم",
          body: senderFirst ? `${senderFirst} قبل طلب المحرم.` : "تم قبول طلب المحرم.",
        };

      case "LIKE_POST":
        return {
          title: "إعجاب جديد",
          body: preview
            ? `“${preview}”`
            : senderFirst
              ? `${senderFirst} أعجب بمنشورك.`
              : "أعجب شخص ما بمنشورك.",
        };

      case "COMMENT_POST":
        return {
          title: "تعليق جديد",
          body: preview
            ? `“${preview}”`
            : senderFirst
              ? `${senderFirst} علّق على منشورك.`
              : "علّق شخص ما على منشورك.",
        };

      case "COMMENT_REPLY":
        return {
          title: "رد على تعليقك",
          body: preview
            ? `“${preview}”`
            : senderFirst
              ? `${senderFirst} ردّ على تعليقك.`
              : "ردّ شخص ما على تعليقك.",
        };

      case "CHAT_MESSAGE":
        return {
          title: senderFirst || "رسالة جديدة",
          body: preview || "لديك رسالة جديدة.",
        };

      case "GROUP_MESSAGE":
        return {
          title: groupName || "رسالة جماعية",
          body:
            preview ||
            (groupName ? `رسالة جديدة في ${groupName}.` : "رسالة جماعية جديدة."),
        };

      case "GROUP_ADDED":
        return {
          title: groupName || "مجموعة",
          body: senderFirst ? `${senderFirst} أضافك إلى المجموعة.` : "تمت إضافتك إلى مجموعة.",
        };
      case "COMMUNITY_INVITE":
        return {
          title: "دعوة إلى مجتمع",
          body: nameArg
            ? `تمت دعوتك إلى ${nameArg}.`
            : "لديك دعوة إلى مجتمع.",
        };


      // -------------------------
      // 💍 Marriage inquiry (AR)
      // -------------------------
      case "MARRIAGE_INQUIRY_REQUEST":
        return {
          title: "طلب زواج",
          body: senderFirst
            ? `${senderFirst} أرسل طلب زواج. اضغط للعرض.`
            : "لديك طلب زواج جديد.",
        };

      case "MARRIAGE_INQUIRY_MAHRAM":
        return {
          title: "تم اختيارك كمحرم",
          body: senderFirst
            ? `${senderFirst} اختارك كمحرم لطلب زواج. اضغط لعرض الملف الشخصي.`
            : "تم اختيارك كمحرم لطلب زواج.",
        };

      case "MARRIAGE_INQUIRY_MAN_DECISION":
        return {
          title: "مطلوب قرار",
          body: senderFirst
            ? `${senderFirst} طلب/طلبت زواج. اضغط للقبول أو الرفض.`
            : "هناك طلب زواج. اضغط للقبول أو الرفض.",
        };

      case "MARRIAGE_INQUIRY_MAHRAM_ACCEPTED":
        return {
          title: "تم قبول المحرم",
          body: "وافق المحرم على طلب الزواج.",
        };

      case "MARRIAGE_INQUIRY_MAHRAM_ACCEPTED_SENT_TO":
        return {
          title: "تم قبول المحرم",
          body: nameArg
            ? `وافق المحرم على طلب الزواج، وتم إرسال الطلب إلى ${nameArg}.`
            : "وافق المحرم على طلب الزواج، وتم إرسال الطلب.",
        };


      case "MARRIAGE_INQUIRY_ACCEPTED":
        return {
          title: "تم قبول طلب الزواج",
          body: senderFirst ? `${senderFirst} قبل طلب الزواج.` : "تم قبول طلب الزواج.",
        };

      case "MARRIAGE_INQUIRY_DECLINED":
        return {
          title: "تم رفض طلب الزواج",
          body: senderFirst ? `${senderFirst} رفض طلب الزواج.` : "تم رفض طلب الزواج.",
        };

      case "MARRIAGE_INQUIRY_GROUP_CREATED":
        return {
          title: "تم إنشاء المجموعة",
          body: "تم إنشاء مجموعة الدردشة لطلب الزواج. اضغط لفتحها.",
        };
    }
  }

  // default EN
  switch (type) {
    case "FOLLOW_USER":
      return {
        title: "New follower",
        body: senderFirst ? `${senderFirst} started following you.` : "Someone started following you.",
      };

    case "FRIEND_REQUEST":
      return {
        title: "Friend request",
        body: senderFirst ? `${senderFirst} sent you a friend request.` : "You received a new friend request.",
      };

    case "FRIEND_ACCEPTED":
      return {
        title: "Friend request accepted",
        body: senderFirst ? `${senderFirst} accepted your friend request.` : "Your friend request was accepted.",
      };

    case "MAHRAM_REQUEST":
      return {
        title: "Mahram request",
        body: senderFirst ? `${senderFirst} sent you a mahram request.` : "You received a new mahram request.",
      };

    case "MAHRAM_ACCEPTED":
      return {
        title: "Mahram request accepted",
        body: senderFirst ? `${senderFirst} accepted your mahram request.` : "Your mahram request was accepted.",
      };

    case "LIKE_POST":
      return {
        title: "New like",
        body: preview
          ? `“${preview}”`
          : senderFirst
            ? `${senderFirst} liked your post.`
            : "Someone liked your post.",
      };

    case "COMMENT_POST":
      return {
        title: "New comment",
        body: preview
          ? `“${preview}”`
          : senderFirst
            ? `${senderFirst} commented on your post.`
            : "Someone commented on your post.",
      };

    case "COMMENT_REPLY":
      return {
        title: "Reply to your comment",
        body: preview
          ? `“${preview}”`
          : senderFirst
            ? `${senderFirst} replied to your comment.`
            : "Someone replied to your comment.",
      };

    case "CHAT_MESSAGE":
      return {
        title: senderFirst || "New message",
        body: preview || "You received a new message.",
      };

    case "GROUP_MESSAGE":
      return {
        title: groupName || "Group message",
        body: preview || (groupName ? `New message in ${groupName}.` : "New group message."),
      };

    case "GROUP_ADDED":
      return {
        title: groupName || "Group",
        body: senderFirst ? `${senderFirst} added you to the group.` : "You were added to a group.",
      };

  case "COMMUNITY_INVITE":
    return {
      title: "Community invite",
      body: nameArg
        ? `You were invited to ${nameArg}.`
        : "You received a community invite.",
    };


    // -------------------------
    // 💍 Marriage inquiry (EN)
    // -------------------------
    case "MARRIAGE_INQUIRY_REQUEST":
      return {
        title: "Marriage inquiry",
        body: senderFirst
          ? `${senderFirst} requested a marriage inquiry. Tap to view.`
          : "You received a marriage inquiry request.",
      };

    case "MARRIAGE_INQUIRY_MAHRAM":
      return {
        title: "You were chosen as a mahram",
        body: senderFirst
          ? `${senderFirst} chose you as her mahram for a marriage inquiry. Tap to view the profile.`
          : "You were chosen as a mahram for a marriage inquiry.",
      };

    case "MARRIAGE_INQUIRY_MAN_DECISION":
      return {
        title: "Decision needed",
        body: senderFirst
          ? `${senderFirst} requested a marriage inquiry. Tap to accept or decline.`
          : "A marriage inquiry needs your decision. Tap to accept or decline.",
      };

    case "MARRIAGE_INQUIRY_MAHRAM_ACCEPTED":
      return {
        title: "Mahram accepted",
        body: "The mahram accepted the marriage inquiry.",
      };

    case "MARRIAGE_INQUIRY_MAHRAM_ACCEPTED_SENT_TO":
      return {
        title: "Mahram accepted",
        body: nameArg
          ? `The mahram accepted the marriage inquiry, and the inquiry was sent to ${nameArg}.`
          : "The mahram accepted the marriage inquiry, and the inquiry was sent.",
      };


    case "MARRIAGE_INQUIRY_ACCEPTED":
      return {
        title: "Marriage inquiry accepted",
        body: senderFirst
          ? `${senderFirst} accepted the marriage inquiry.`
          : "The marriage inquiry was accepted.",
      };

    case "MARRIAGE_INQUIRY_DECLINED":
      return {
        title: "Marriage inquiry declined",
        body: senderFirst
          ? `${senderFirst} declined the marriage inquiry.`
          : "The marriage inquiry was declined.",
      };

    case "MARRIAGE_INQUIRY_GROUP_CREATED":
      return {
        title: "Group created",
        body: "A group chat for the marriage inquiry was created. Tap to open.",
      };
  }
}

// ✅ Optional: extra safety so a weird notif_type never crashes the function
function safeTemplate(
  locale: LocaleCode,
  notifType: string,
  args: Record<string, string>,
): { title: string; body: string } {
  try {
    return template(locale, notifType as NotifType, args);
  } catch {
    return { title: "New notification", body: "" };
  }
}

serve(async (req: Request) => {
  try {
    const body = await req.json().catch(() => ({}));

    // ✅ NEW payload
    const targetUserId = body?.target_user_id as string | undefined;
    const notifType = body?.notif_type as string | undefined; // accept string, we validate via safeTemplate
    const args =
      (body?.args && typeof body.args === "object")
        ? (body.args as Record<string, unknown>)
        : {};
    const dataIncoming =
      (body?.data && typeof body.data === "object") ? body.data : {};

    console.log("send_push incoming keys:", Object.keys(body ?? {}));
    console.log("send_push new payload:", { targetUserId, notifType });

    // ✅ OLD payload
    const oldFcmToken = body?.fcm_token as string | undefined;
    const oldTitle = body?.title as string | undefined;
    const oldMessageBody = body?.body as string | undefined;

    // -------------------------
    // Resolve fcm_token + locale
    // -------------------------
    let fcmToken: string | null = null;
    let locale: LocaleCode = "en";

    if (targetUserId && notifType) {
      const supabaseUrl = Deno.env.get("SUPABASE_URL");
      const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

      if (!supabaseUrl || !serviceRoleKey) {
        return new Response(
          JSON.stringify({
            error: "Missing SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY in secrets",
          }),
          { status: 500 },
        );
      }

      const admin = createClient(supabaseUrl, serviceRoleKey);

      const { data: profile, error } = await admin
        .from("profiles")
        .select("fcm_token, locale")
        .eq("id", targetUserId)
        .maybeSingle();

      if (error) {
        return new Response(
          JSON.stringify({ error: `Failed to fetch profile: ${error.message}` }),
          { status: 500 },
        );
      }

      fcmToken = (profile?.fcm_token as string | null) ?? null;
      locale = normalizeLocale(profile?.locale);
    } else {
      fcmToken = oldFcmToken ?? null;
      locale = "en";
    }

    if (!fcmToken) {
      return new Response(
        JSON.stringify({ error: "Missing fcm_token / no token for target user" }),
        { status: 400 },
      );
    }

    // -------------------------
    // Build localized title/body
    // -------------------------
    let finalTitle = safeStr(oldTitle) || "New notification";
    let finalBody = safeStr(oldMessageBody) || "";

    if (targetUserId && notifType) {
      const argsStr: Record<string, string> = {};
      for (const [k, v] of Object.entries(args)) {
        argsStr[k] = String(v ?? "");
      }

      const res = safeTemplate(locale, notifType, argsStr);
      finalTitle = safeStr(res?.title) || finalTitle || "New notification";
      finalBody = safeStr(res?.body) || finalBody || "";
    }

    // -------------------------
    // Send to FCM
    // -------------------------
    const payload = {
      message: {
        token: fcmToken,
        notification: {
          title: finalTitle,
          body: finalBody,
        },
        data: toStringMap(dataIncoming),
      },
    };

    const projectId = Deno.env.get("FIREBASE_PROJECT_ID") ?? "ummah-chat-e8a4e";

    const firebaseRes = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${await getAccessToken()}`,
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
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 500,
    });
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

  let pem = rawPrivateKey.trim();

  if (pem.includes("\\n")) {
    pem = pem.replace(/\\n/g, "\n");
  }

  pem = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .trim();

  const base64Key = pem.replace(/\r?\n/g, "").replace(/\s+/g, "");

  if (!base64Key) {
    throw new Error("Empty private key after cleaning");
  }

  let binaryDer: Uint8Array;
  try {
    const binaryDerString = atob(base64Key);
    binaryDer = new Uint8Array([...binaryDerString].map((c) => c.charCodeAt(0)));
  } catch (e) {
    console.error("❌ Failed to decode base64 private key:", e);
    throw new Error("Failed to decode base64");
  }

  const key = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
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
    return btoa(input).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
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
