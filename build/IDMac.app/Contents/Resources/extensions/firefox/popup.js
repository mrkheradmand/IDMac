document.addEventListener("DOMContentLoaded", () => {
  const statusDot = document.getElementById("statusDot");
  const statusText = document.getElementById("statusText");
  const statusDesc = document.getElementById("statusDesc");
  const captureToggle = document.getElementById("captureToggle");
  const openAppBtn = document.getElementById("openAppBtn");

  // Query background service for status
  browser.runtime.sendMessage({ action: "getStatus" }, (response) => {
    if (response) {
      updateUI(response.isConnected, response.isEnabled);
    } else {
      updateUI(false, true);
    }
  });

  // Toggle switch handler
  captureToggle.addEventListener("change", (e) => {
    const enabled = e.target.checked;
    browser.runtime.sendMessage({ action: "toggleCapture", value: enabled });
  });

  // Open App Button
  openAppBtn.addEventListener("click", () => {
    // Ping server or open custom scheme
    fetch("http://127.0.0.1:23485/health")
      .then(() => {
        window.close();
      })
      .catch(() => {
        alert("IDMac is not running. Please start IDMac from your Applications folder.");
      });
  });

  function updateUI(connected, enabled) {
    captureToggle.checked = enabled;

    if (connected) {
      statusDot.className = "status-dot connected";
      statusText.textContent = "IDMac Connected";
      statusDesc.textContent = enabled
        ? "Downloads in Firefox are being automatically captured and accelerated."
        : "Capture is paused in settings above.";
    } else {
      statusDot.className = "status-dot disconnected";
      statusText.textContent = "IDMac Offline";
      statusDesc.textContent = "Start IDMac on your Mac to enable multi-stream acceleration.";
    }
  }
});
