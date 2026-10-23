// IDMac Firefox Content Script - Link Detection Helper
(() => {
  // Common downloadable binary extensions
  const DOWNLOAD_EXTENSIONS = /\.(zip|rar|7z|tar|gz|tgz|bz2|dmg|iso|pkg|exe|msi|bin|mp4|mkv|avi|mov|mp3|flac|wav|pdf|epub)$/i;

  document.addEventListener("click", (e) => {
    const link = e.target.closest("a");
    if (!link || !link.href) return;

    const url = link.href;
    if (url.startsWith("http://") || url.startsWith("https://")) {
      const cleanUrl = url.split("?")[0].split("#")[0];
      if (DOWNLOAD_EXTENSIONS.test(cleanUrl)) {
        // Link will naturally trigger browser.downloads.onCreated, which the background script captures
      }
    }
  }, true);
})();
