const statusTitle = document.getElementById('status-title');
const statusBody = document.getElementById('status-body');
const openBtn = document.getElementById('open-btn');

openBtn.addEventListener('click', () => {
  chrome.runtime.sendMessage({ type: 'openBloom' });
});

chrome.runtime.sendMessage({ type: 'getStatus' }, (status) => {
  if (chrome.runtime.lastError || !status || !status.connected) {
    statusTitle.textContent = 'Connect Bloom app';
    statusBody.textContent = 'Open Bloom → Focus → Websites to block and click Register browser bridge.';
    return;
  }
  const count = new Set([...(status.blockedDomains || []), ...(status.managedDomains || [])]).size;
  if (!status.enabled) {
    statusTitle.textContent = 'Website blocking is off';
    statusBody.textContent = `${count} ${count === 1 ? 'domain' : 'domains'} saved in Bloom.`;
  } else if (status.accessAllowed) {
    const mins = Math.max(1, Math.ceil((status.remainingMillis || 0) / 60000));
    statusTitle.textContent = 'Screen time active';
    statusBody.textContent = `About ${mins} min remaining before ${count} ${count === 1 ? 'domain' : 'domains'} re-block.`;
  } else {
    statusTitle.textContent = 'Website protection is on';
    statusBody.textContent = `Blocking ${count} ${count === 1 ? 'domain' : 'domains'} with Bloom block page.`;
  }
});
