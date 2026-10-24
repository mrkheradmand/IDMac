// ==============================================================================
// IDMac Firefox Extension - Background Service
// ==============================================================================

const IDMAC_SERVER = "http://127.0.0.1:23485";
let isEnabled = true;
let isConnected = false;

// Initialize preferences
browser.storage.local.get(["captureDownloads"], (result) => {
  if (result.captureDownloads !== undefined) {
    isEnabled = result.captureDownloads;
  } else {
    browser.storage.local.set({ captureDownloads: true });
    isEnabled = true;
  }
  checkHealth();
});

// Listen for storage changes
browser.storage.onChanged.addListener((changes) => {
  if (changes.captureDownloads) {
    isEnabled = changes.captureDownloads.newValue;
    updateBadge();
  }
});

// Health check with IDMac Local Server
async function checkHealth() {
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 1500);

    const res = await fetch(`${IDMAC_SERVER}/health`, {
      method: "GET",
      signal: controller.signal
    });
    clearTimeout(timeoutId);

    if (res.ok) {
      const data = await res.json();
      isConnected = data.status === "ok";
    } else {
      isConnected = false;
    }
  } catch (err) {
    isConnected = false;
  }
  updateBadge();
  return isConnected;
}

// Update Extension icon badge
function updateBadge() {
  if (!isEnabled) {
    browser.browserAction.setBadgeText({ text: "PAUSE" });
    browser.browserAction.setBadgeBackgroundColor({ color: "#FF9500" });
    browser.browserAction.setTitle({ title: "IDMac: Capture Paused" });
  } else if (isConnected) {
    browser.browserAction.setBadgeText({ text: "ON" });
    browser.browserAction.setBadgeBackgroundColor({ color: "#34C759" });
    browser.browserAction.setTitle({ title: "IDMac: Connected & Accelerating" });
  } else {
    browser.browserAction.setBadgeText({ text: "OFF" });
    browser.browserAction.setBadgeBackgroundColor({ color: "#8E8E93" });
    browser.browserAction.setTitle({ title: "IDMac: App Not Detected" });
  }
}

// Periodic Health Check every 10 seconds
setInterval(checkHealth, 10000);
checkHealth();

const interceptedDownloadIds = new Set();

// Intercept browser downloads
browser.downloads.onCreated.addListener(async (item) => {
  if (!isEnabled) return;

  const url = item.url || "";

  // Skip non-HTTP links and internal browser URLs
  if (!url.startsWith("http://") && !url.startsWith("https://")) {
    return;
  }

  // Skip Firefox Addon (.xpi) installations
  if (url.toLowerCase().endsWith(".xpi") || item.mime === "application/x-xpinstall") {
    return;
  }

  // Check if IDMac is online (check cached state first to eliminate network lag)
  if (!isConnected) {
    const alive = await checkHealth();
    if (!alive) {
      console.log("IDMac is not running; letting Firefox handle download natively.");
      return;
    }
  }

  interceptedDownloadIds.add(item.id);

  // Instantly pause and cancel native Firefox download
  cancelNativeDownload(item.id);

  // Forward to IDMac
  sendToIDMac(url, item.filename, item.referrer, item.id);
});

// Continuously enforce cancellation if Gecko transitions state later
browser.downloads.onChanged.addListener((delta) => {
  if (interceptedDownloadIds.has(delta.id)) {
    if (delta.state && delta.state.current === "in_progress") {
      cancelNativeDownload(delta.id);
    }
  }
});

function cancelNativeDownload(id) {
  try {
    browser.downloads.pause(id).catch(() => {});
  } catch (e) {}

  browser.downloads.cancel(id).then(() => {
    browser.downloads.erase({ id: id }).catch(() => {});
  }).catch(() => {
    // Retry in 50ms and 150ms in case the download record is still initializing in Gecko
    setTimeout(() => {
      browser.downloads.cancel(id).then(() => {
        browser.downloads.erase({ id: id }).catch(() => {});
      }).catch(() => {});
    }, 50);
    setTimeout(() => {
      browser.downloads.cancel(id).then(() => {
        browser.downloads.erase({ id: id }).catch(() => {});
      }).catch(() => {});
    }, 150);
  });
}

// Forward download task to IDMac
async function sendToIDMac(url, filename = "", referrer = "", downloadId = null) {
  try {
    const res = await fetch(`${IDMAC_SERVER}/add`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        url: url,
        filename: filename,
        referrer: referrer
      })
    });

    if (res.ok) {
      notify("IDMac Accelerating", `Downloading: ${filename || url}`);
    } else {
      notify("IDMac Error", "Failed to queue download in IDMac.");
    }
  } catch (err) {
    if (downloadId) {
      interceptedDownloadIds.delete(downloadId);
      try {
        browser.downloads.resume(downloadId);
      } catch (e) {}
    }
    notify("IDMac Connection Lost", "Please ensure IDMac is running on your Mac.");
  }
}

// Show native notification
function notify(title, message) {
  browser.notifications.create({
    type: "basic",
    iconUrl: "icons/icon-48.png",
    title: title,
    message: message
  });
}

// Context Menus
browser.contextMenus.create({
  id: "idmac-download-link",
  title: "Download with IDMac",
  contexts: ["link"]
});

browser.contextMenus.create({
  id: "idmac-download-media",
  title: "Download Media with IDMac",
  contexts: ["video", "audio", "image"]
});

browser.contextMenus.onClicked.addListener((info, tab) => {
  if (info.menuItemId === "idmac-download-link" && info.linkUrl) {
    sendToIDMac(info.linkUrl, "", tab ? tab.url : "");
  } else if (info.menuItemId === "idmac-download-media" && info.srcUrl) {
    sendToIDMac(info.srcUrl, "", tab ? tab.url : "");
  }
});

// Message listener for popup
browser.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.action === "getStatus") {
    checkHealth().then((connected) => {
      sendResponse({ isConnected: connected, isEnabled: isEnabled });
    });
    return true; // Asynchronous reply
  }
  if (message.action === "toggleCapture") {
    isEnabled = message.value;
    browser.storage.local.set({ captureDownloads: isEnabled });
    updateBadge();
    sendResponse({ success: true, isEnabled: isEnabled });
  }
});

