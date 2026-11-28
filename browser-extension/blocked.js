const params = new URLSearchParams(window.location.search);
const host = (params.get('host') || '').trim();
const isManaged = params.get('managed') === '1';

const badge = document.getElementById('badge');
const title = document.getElementById('title');
const reason = document.getElementById('reason');
const banner = document.getElementById('unlocked-banner');
const balancePill = document.getElementById('balance-pill');
const unlockedHost = document.getElementById('unlocked-host');
const primaryBtn = document.getElementById('primary-btn');
const continueBtn = document.getElementById('continue-btn');
const backBtn = document.getElementById('back-btn');

badge.textContent = isManaged ? 'Family Rule' : 'Bloom Focus';
title.textContent = host ? `${host} is blocked by Bloom` : 'This site is blocked by Bloom';
reason.textContent = isManaged
  ? 'A parent-managed rule is blocking this website on this Mac. Complete Exercise, Study, Reading, or Tasks to earn screen time, or start an earned session in Bloom.'
  : 'Website protection is currently active on this Mac. Complete Exercise, Study, Reading, or Tasks to earn screen time, or start an earned session in Bloom.';

primaryBtn.addEventListener('click', () => {
  chrome.runtime.sendMessage({ type: 'openBloom' });
});

continueBtn.addEventListener('click', () => {
  if (host) {
    window.location.replace(`https://${host}`);
  }
});

backBtn.addEventListener('click', () => {
  if (window.history.length > 1) {
    window.history.back();
  } else {
    window.close();
  }
});

async function refreshStatus() {
  const status = await new Promise((resolve) => {
    chrome.runtime.sendMessage({ type: 'getStatus' }, (response) => {
      if (chrome.runtime.lastError) resolve(null);
      else resolve(response);
    });
  });
  if (!status || !status.connected) return;

  const unlocked = !status.enabled || status.accessAllowed;
  if (unlocked && host) {
    unlockedHost.textContent = host;
    banner.hidden = false;
    balancePill.hidden = true;
    primaryBtn.hidden = true;
    continueBtn.hidden = false;
  } else {
    banner.hidden = true;
    primaryBtn.hidden = false;
    continueBtn.hidden = true;
    if (status.creditsEnabled && typeof status.creditBalanceMinutes === 'number') {
      const minutes = status.creditBalanceMinutes;
      if (minutes >= 1) {
        balancePill.textContent = `${Math.floor(minutes)} min of earned screen time ready in Bloom.`;
      } else if (minutes > 0) {
        balancePill.textContent = 'Less than 1 min earned. Complete an activity in Bloom to earn more.';
      } else {
        balancePill.textContent = '0 min earned right now. Complete Exercise, Study, Reading, or Tasks in Bloom.';
      }
      balancePill.hidden = false;
    } else {
      balancePill.hidden = true;
    }
  }
}

void refreshStatus();
setInterval(() => {
  void refreshStatus();
}, 2000);
