// ==UserScript==
// @name         GitHub Saved Replies – Smart Auto Importer
// @namespace    https://github.com/kjanat
// @version      5.0
// @description  Automatically import missing GitHub saved replies, with JSON source and no UI if done.
// @match        https://github.com/settings/replies
// @grant        none
// ==/UserScript==

(async function () {
  "use strict";

  const JSON_SOURCE_URL =
    "https://raw.githubusercontent.com/kjanat/kjanat/refs/heads/master/scripts/tampermonkey/saved-replies.json";

  const delay = (ms) => new Promise((res) => setTimeout(res, ms));

  const getExistingReplies = () => {
    const items = document.querySelectorAll(".js-saved-reply-list-item");
    return [...items].map((el) => {
      const name =
        el.querySelector(".listgroup-item-title span")?.innerText?.trim() || "";
      const body =
        el.querySelector(".listgroup-item-body span")?.innerText?.trim() || "";
      return { name, body };
    });
  };

  const simulateInput = (el, val) => {
    el.focus();
    el.value = val;
    el.dispatchEvent(new Event("input", { bubbles: true }));
    el.dispatchEvent(new Event("change", { bubbles: true }));
    el.blur();
  };

  const waitFor = async (selector, timeout = 5000) => {
    let elapsed = 0;
    while (elapsed < timeout) {
      const el = document.querySelector(selector);
      if (el) return el;
      await delay(100);
      elapsed += 100;
    }
    throw new Error(`Timeout waiting for ${selector}`);
  };

  const importNextReply = async (replies) => {
    const index = parseInt(
      localStorage.getItem("savedReplyImportIndex") || "0",
      10,
    );
    const existing = getExistingReplies();

    let current = 0;
    for (let i = 0; i < replies.length; i++) {
      const r = replies[i];
      const exists = existing.some(
        (e) =>
          e.name === r.name &&
          e.body.replace(/\s+/g, " ").trim() ===
            r.body.replace(/\s+/g, " ").trim(),
      );
      if (!exists) {
        if (current === index) {
          const form = await waitFor('form[action="/settings/replies"]');
          const titleInput = form.querySelector('input[name="title"]');
          const bodyArea = form.querySelector('textarea[name="body"]');
          const submitBtn = form.querySelector('button[type="submit"]');

          console.log(`⏳ Importing [${i + 1}/${replies.length}]: ${r.name}`);
          simulateInput(titleInput, r.name);
          simulateInput(bodyArea, r.body);

          let tries = 0;
          const maxRetries = 30; // Parameterize this value if needed
          const retryDelay = 100; // Parameterize this value if needed
          while (submitBtn.disabled && tries++ < maxRetries)
            await delay(retryDelay);

          if (!submitBtn.disabled) {
            localStorage.setItem("savedReplyImportIndex", current + 1);
            submitBtn.click();

            // Wait for GitHub to save it
            let maxTries = 40;
            while (maxTries-- > 0) {
              await delay(500);
              const updated = getExistingReplies();
              const nowExists = updated.some(
                (e) =>
                  e.name === r.name &&
                  e.body.replace(/\s+/g, " ").trim() ===
                    r.body.replace(/\s+/g, " ").trim(),
              );
              if (nowExists) break;
            }

            await delay(1000);
            location.reload();
          } else {
            console.warn(`⚠️ Submit still disabled for ${r.name}`);
          }
          return;
        }
        current++;
      }
    }

    localStorage.removeItem("savedReplyImportIndex");
    console.info("✅ All saved replies are present.");
  };

  const fetchReplies = async () => {
    try {
      const res = await fetch(JSON_SOURCE_URL);
      if (!res.ok) throw new Error("Failed to fetch replies JSON");
      return await res.json();
    } catch (e) {
      console.error("❌ Failed to load external replies:", e);
      return [];
    }
  };

  const init = async () => {
    const replies = await fetchReplies();
    if (!Array.isArray(replies) || replies.length === 0) return;

    const existing = getExistingReplies();
    const missing = replies.filter((reply) => {
      return !existing.some(
        (e) =>
          e.name === reply.name &&
          e.body.replace(/\s+/g, " ").trim() ===
            reply.body.replace(/\s+/g, " ").trim(),
      );
    });

    if (missing.length === 0) return; // no buttons, no alerts, just silently bail out

    // Only trigger import chain if in progress
    if (localStorage.getItem("savedReplyImportIndex")) {
      await importNextReply(replies);
      return;
    }

    // UI trigger button (only if needed)
    const container = document.querySelector(".Layout-main");
    if (!container) return;

    const btn = document.createElement("button");
    btn.textContent = "📥 Auto-Import Missing Saved Replies";
    btn.style = `
		margin:1em;
		padding:0.6em 1.4em;
		background:#2da44e;
		color:white;
		font-size:16px;
		border:none;
		border-radius:6px;
		cursor:pointer;
		font-weight:600;
	  `;
    btn.onclick = () => {
      localStorage.setItem("savedReplyImportIndex", "0");
      location.reload();
    };

    container.prepend(btn);
  };

  init();
})();
