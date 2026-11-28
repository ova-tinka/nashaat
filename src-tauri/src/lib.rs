#[cfg(target_os = "macos")]
struct PendingDeepLink(std::sync::Mutex<Option<String>>);

#[cfg(target_os = "macos")]
fn route_from_deep_link(url: &url::Url) -> Option<String> {
  if url.scheme() != "bloomexercise" {
    return None;
  }
  let host = url.host_str().unwrap_or("");
  let path = url.path();
  let is_focus = host == "focus" || path == "/focus" || (host.is_empty() && path == "focus");
  if !is_focus {
    return None;
  }
  let section = url.query_pairs().find_map(|(k, v)| {
    if k == "section" && matches!(v.as_ref(), "focus" | "apps" | "websites" | "rules" | "earned") {
      Some(v.into_owned())
    } else {
      None
    }
  });
  match section {
    Some(value) => Some(format!("/focus?section={value}")),
    None => Some("/focus".to_string()),
  }
}

#[cfg(target_os = "macos")]
#[tauri::command]
fn take_pending_deep_link(state: tauri::State<'_, PendingDeepLink>) -> Option<String> {
  state.0.lock().ok().and_then(|mut guard| guard.take())
}

#[cfg(target_os = "macos")]
async fn dispatch_filter_request(
  action: String,
  domains: Option<Vec<String>>,
  apps: Option<Vec<String>>,
  timing: Option<serde_json::Value>,
  targets: Option<serde_json::Value>,
  usage: Option<serde_json::Value>,
  account_id: Option<String>,
  strict: Option<bool>,
  display_balance: Option<serde_json::Value>,
) -> Result<serde_json::Value, String> {
  if !matches!(action.as_str(), "activate" | "start" | "stop" | "clearManualDomains" | "cleanupHosts" | "hostsRecoveryStatus" | "hostsPolicyStatus" | "syncHostsManaged" | "enrollHosts" | "startHostsUsage" | "stopHostsUsage" | "clearManualApps" | "status" | "appStatus" | "clock" | "startCreditAccess" | "endCreditAccess" | "activateApps" | "chooseApp" | "listInstalledApps" | "startApps" | "stopApps" | "getUsageAccess" | "startUsageAccess" | "closeUsageAccess" | "clearUsageAccess" | "openAccessibilitySettings" | "openLoginItemsSettings" | "installBrowserBridge" | "installBrowserProtection" | "openBrowserPolicyProfile" | "browserProtectionStatus" | "selfCheck" | "syncDisplayBalance" | "syncManagedRules") {
    return Err("Invalid filter action.".into());
  }
  let (display_credit_enabled, display_credit_balance_minutes) = if action == "syncDisplayBalance" {
    let value = display_balance.as_ref().ok_or("Missing display balance details.")?;
    let enabled = value.get("creditsEnabled").and_then(|v| v.as_bool()).ok_or("Invalid credits flag.")?;
    let minutes = value.get("balanceMinutes").and_then(|v| v.as_f64()).ok_or("Invalid balance amount.")?;
    if !minutes.is_finite() || minutes < 0.0 || minutes > 1_000_000.0 {
      return Err("Invalid balance amount.".into());
    }
    (Some(enabled), Some(minutes))
  } else {
    (None, None)
  };
  if domains.as_ref().is_some_and(|items| items.len() > 500 || items.iter().any(|item| item.len() > 2048)) {
    return Err("Invalid website selection.".into());
  }
  if apps.as_ref().is_some_and(|items| items.len() > 500 || items.iter().any(|item| item.len() > 255)) {
    return Err("Invalid app selection.".into());
  }
  if action == "syncManagedRules" && !account_id.as_ref().is_some_and(|id| !id.is_empty() && id.len() <= 64) {
    return Err("Invalid account for managed blocking rules.".into());
  }
  let valid_uuid = |value: &str| value.len() == 36 && value.bytes().enumerate().all(|(index, byte)| {
    if [8, 13, 18, 23].contains(&index) { byte == b'-' } else { byte.is_ascii_hexdigit() }
  });
  let (credit_request_id, credit_device_key, credit_minutes, credit_access_token) = if action == "startCreditAccess" {
    let value = timing.as_ref().ok_or("Missing screen-time details.")?;
    let request_id = value.get("requestId").and_then(|v| v.as_str()).ok_or("Invalid request identifier.")?;
    let device_key = value.get("deviceKey").and_then(|v| v.as_str()).ok_or("Invalid device identifier.")?;
    let minutes = value.get("minutes").and_then(|v| v.as_f64()).ok_or("Invalid screen-time duration.")?;
    let access_token = value.get("accessToken").and_then(|v| v.as_str()).ok_or("Sign in to use screen time.")?;
    if !valid_uuid(request_id) || !valid_uuid(device_key) || !minutes.is_finite() || minutes <= 0.0 || minutes > 1440.0
      || access_token.is_empty() || access_token.len() > 8192 {
      return Err("Invalid screen-time details.".into());
    }
    (Some(request_id.to_owned()), Some(device_key.to_owned()), Some(minutes), Some(access_token.to_owned()))
  } else { (None, None, None, None) };
  let credit_websites = targets.as_ref().and_then(|v| v.get("websites")).and_then(|v| v.as_bool());
  let credit_apps = targets.as_ref().and_then(|v| v.get("apps")).and_then(|v| v.as_bool());
  if action == "startCreditAccess" && credit_websites != Some(true) && credit_apps != Some(true) {
    return Err("Choose an active blocking target.".into());
  }
  if (action == "startCreditAccess" && credit_websites == Some(true))
    || (action == "endCreditAccess" && credit_websites != Some(false)) {
    if !account_id.as_ref().is_some_and(|id| valid_uuid(id)) {
      return Err("Invalid account for website screen time.".into());
    }
  }
  let mut session_id: Option<String> = None;
  let mut user_id: Option<String> = None;
  let mut usage_request_id: Option<String> = None;
  let mut usage_device_key: Option<String> = None;
  let mut usage_requested_millis: Option<i64> = None;
  let mut usage_access_token: Option<String> = None;
  let mut hosts_grant_kind: Option<String> = None;
  if matches!(action.as_str(), "startUsageAccess" | "closeUsageAccess" | "clearUsageAccess" | "hostsPolicyStatus" | "syncHostsManaged" | "enrollHosts" | "startHostsUsage" | "stopHostsUsage") {
    let value = usage.as_ref().ok_or("Missing usage-session details.")?;
    let user = value.get("userId").and_then(|v| v.as_str()).ok_or("Missing account.")?;
    if user.is_empty() || user.len() > 64 || (matches!(action.as_str(), "hostsPolicyStatus" | "syncHostsManaged" | "enrollHosts" | "startHostsUsage" | "stopHostsUsage") && !valid_uuid(user)) { return Err("Invalid account.".into()); }
    user_id = Some(user.to_string());
    if matches!(action.as_str(), "syncHostsManaged" | "enrollHosts" | "startHostsUsage") {
      let token = value.get("accessToken").and_then(|v| v.as_str()).ok_or("Sign in to sync website rules.")?;
      if token.is_empty() || token.len() > 8192 { return Err("Invalid account session.".into()); }
      usage_access_token = Some(token.to_owned());
    }
    if action == "startHostsUsage" {
      let key = value.get("deviceKey").and_then(|v| v.as_str()).ok_or("Invalid device identifier.")?;
      let kind = value.get("kind").and_then(|v| v.as_str()).ok_or("Invalid screen-time mode.")?;
      if !valid_uuid(key) || !matches!(kind, "easy" | "countdown") { return Err("Invalid screen-time details.".into()); }
      if kind == "countdown" {
        let id = value.get("requestId").and_then(|v| v.as_str()).ok_or("Invalid request identifier.")?;
        if !valid_uuid(id) { return Err("Invalid request identifier.".into()); }
        usage_request_id = Some(id.to_owned());
      }
      usage_device_key = Some(key.to_owned());
      hosts_grant_kind = Some(kind.to_owned());
    }
    if action == "clearUsageAccess" || action == "stopHostsUsage" {
      let session = value.get("sessionId").and_then(|v| v.as_str()).ok_or("Missing session.")?;
      if session.is_empty() || session.len() > 64 || (action == "stopHostsUsage" && !valid_uuid(session)) { return Err("Invalid session.".into()); }
      session_id = Some(session.to_string());
    }
    if action == "startUsageAccess" {
      let request_id = value.get("requestId").and_then(|v| v.as_str()).ok_or("Invalid request identifier.")?;
      let device_key = value.get("deviceKey").and_then(|v| v.as_str()).ok_or("Invalid device identifier.")?;
      let requested = value.get("requestedMillis").and_then(|v| v.as_i64()).ok_or("Invalid screen-time amount.")?;
      let token = value.get("accessToken").and_then(|v| v.as_str()).ok_or("Sign in to use screen time.")?;
      if !valid_uuid(user) || !valid_uuid(request_id) || !valid_uuid(device_key) || !(1000..=604_800_000).contains(&requested)
        || token.is_empty() || token.len() > 8192 { return Err("Invalid usage-session details.".into()); }
      usage_request_id = Some(request_id.to_owned());
      usage_device_key = Some(device_key.to_owned());
      usage_requested_millis = Some(requested);
      usage_access_token = Some(token.to_owned());
    }
  }
  tauri::async_runtime::spawn_blocking(move || {
    use std::ffi::{CStr, CString, c_char, c_void};
    use std::sync::{OnceLock, mpsc};
    use std::time::Duration;

    type Callback = unsafe extern "C" fn(*mut c_void, *const c_char);
    type Request = unsafe extern "C" fn(*const c_char, *mut c_void, Callback);
    static REQUEST: OnceLock<Result<usize, String>> = OnceLock::new();
    let request_fn = REQUEST.get_or_init(|| {
      let executable = std::env::current_exe().map_err(|_| "Could not locate Bloom.")?;
      let sibling = executable.parent().ok_or("Could not locate Bloom.")?.join("libBloomFilterHost.dylib");
      let library = if sibling.is_file() { sibling } else if cfg!(debug_assertions) {
        std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("macos/build/libBloomFilterHost.dylib")
      } else { return Err("Bloom's macOS protection library is not installed.".to_string()) };
      let path = CString::new(library.to_string_lossy().as_bytes()).map_err(|_| "Invalid library path.")?;
      // Keep the library loaded for the life of the process: requests may complete asynchronously.
      let handle = unsafe { libc::dlopen(path.as_ptr(), libc::RTLD_NOW | libc::RTLD_LOCAL) };
      if handle.is_null() { return Err("Could not load Bloom's macOS protection library.".to_string()) }
      let symbol = unsafe { libc::dlsym(handle, c"bloom_filter_request".as_ptr()) };
      if symbol.is_null() { return Err("Bloom's macOS protection library is incompatible.".to_string()) }
      Ok(symbol as usize)
    }).as_ref().map_err(Clone::clone)?;
    let input = serde_json::to_string(&serde_json::json!({ "action": action, "domains": domains, "apps": apps,
      "creditRequestId": credit_request_id, "creditDeviceKey": credit_device_key,
      "creditMinutes": credit_minutes, "creditAccessToken": credit_access_token,
      "usageRequestId": usage_request_id, "usageDeviceKey": usage_device_key,
      "usageRequestedMillis": usage_requested_millis, "usageAccessToken": usage_access_token, "hostsGrantKind": hosts_grant_kind,
      "creditWebsites": credit_websites, "creditApps": credit_apps,
      "sessionId": session_id, "userId": user_id, "accountId": account_id, "strict": strict,
      "displayCreditEnabled": display_credit_enabled, "displayCreditBalanceMinutes": display_credit_balance_minutes }))
      .map_err(|_| "Could not prepare the protection request.")?;
    let input = CString::new(input).map_err(|_| "Invalid protection request.")?;
    let (sender, receiver) = mpsc::sync_channel::<Result<String, String>>(1);
    unsafe extern "C" fn completed(context: *mut c_void, response: *const c_char) {
      // The callback is invoked once, even if the receiver has already timed out.
      let sender = unsafe { Box::from_raw(context as *mut mpsc::SyncSender<Result<String, String>>) };
      let result = if response.is_null() { Err("The macOS protection response was empty.".to_string()) }
        else { unsafe { CStr::from_ptr(response) }.to_str().map(str::to_owned).map_err(|_| "The macOS protection response was invalid.".to_string()) };
      let _ = sender.send(result);
    }
    let timeout = if action == "chooseApp" || action == "cleanupHosts" || action == "enrollHosts" { Duration::from_secs(300) }
      else if action == "startUsageAccess" { Duration::from_secs(130) }
      else if action == "startCreditAccess" { Duration::from_secs(90) }
      else if action == "syncHostsManaged" || action == "startHostsUsage" { Duration::from_secs(70) }
      else if action == "stopHostsUsage" { Duration::from_secs(30) } else { Duration::from_secs(20) };
    let context = Box::into_raw(Box::new(sender)) as *mut c_void;
    let request: Request = unsafe { std::mem::transmute(*request_fn) };
    unsafe { request(input.as_ptr(), context, completed) };
    let output = receiver.recv_timeout(timeout).map_err(|_| "The macOS protection request did not respond. Check system permissions and try again.")??;
    if output.len() > 100_000 { return Err("The macOS protection response was too large.".to_string()) }
    serde_json::from_str(&output).map_err(|_| "The macOS protection response was invalid.".to_string())
  }).await.map_err(|_| "The macOS filter request failed.".to_string())?
}

#[cfg(target_os = "macos")]
#[tauri::command]
async fn macos_blocking_status(action: String, usage: Option<serde_json::Value>) -> Result<serde_json::Value, String> {
  if !matches!(action.as_str(), "status" | "appStatus" | "clock" | "hostsRecoveryStatus" | "hostsPolicyStatus" | "openAccessibilitySettings" | "openLoginItemsSettings" | "browserProtectionStatus" | "selfCheck") {
    return Err("Invalid blocking status operation.".into());
  }
  dispatch_filter_request(action, None, None, None, None, usage, None, None, None).await
}

#[cfg(target_os = "macos")]
#[tauri::command]
async fn macos_manage_website_rules(
  action: String,
  domains: Option<Vec<String>>,
  usage: Option<serde_json::Value>,
  account_id: Option<String>,
  strict: Option<bool>,
) -> Result<serde_json::Value, String> {
  if !matches!(action.as_str(), "activate" | "start" | "stop" | "clearManualDomains" | "cleanupHosts" | "syncHostsManaged" | "enrollHosts" | "installBrowserBridge" | "installBrowserProtection" | "openBrowserPolicyProfile" | "syncManagedRules") {
    return Err("Invalid website rule operation.".into());
  }
  dispatch_filter_request(action, domains, None, None, None, usage, account_id, strict, None).await
}

#[cfg(target_os = "macos")]
#[tauri::command]
async fn macos_manage_app_rules(action: String, apps: Option<Vec<String>>) -> Result<serde_json::Value, String> {
  if !matches!(action.as_str(), "activateApps" | "chooseApp" | "listInstalledApps" | "startApps" | "stopApps" | "clearManualApps") {
    return Err("Invalid app rule operation.".into());
  }
  dispatch_filter_request(action, None, apps, None, None, None, None, None, None).await
}

#[cfg(target_os = "macos")]
#[tauri::command]
async fn macos_credit_session(
  action: String,
  timing: Option<serde_json::Value>,
  targets: Option<serde_json::Value>,
  account_id: Option<String>,
  display_balance: Option<serde_json::Value>,
) -> Result<serde_json::Value, String> {
  if !matches!(action.as_str(), "startCreditAccess" | "endCreditAccess" | "syncDisplayBalance") {
    return Err("Invalid credit session operation.".into());
  }
  dispatch_filter_request(action, None, None, timing, targets, None, account_id, None, display_balance).await
}

#[cfg(target_os = "macos")]
#[tauri::command]
async fn macos_usage_session(action: String, usage: Option<serde_json::Value>) -> Result<serde_json::Value, String> {
  if !matches!(action.as_str(), "getUsageAccess" | "startUsageAccess" | "closeUsageAccess" | "clearUsageAccess" | "startHostsUsage" | "stopHostsUsage") {
    return Err("Invalid usage session operation.".into());
  }
  dispatch_filter_request(action, None, None, None, None, usage, None, None, None).await
}

#[cfg(target_os = "macos")]
fn valid_uuid_str(value: &str) -> bool {
  value.len() == 36 && value.bytes().enumerate().all(|(index, byte)| {
    if [8, 13, 18, 23].contains(&index) { byte == b'-' } else { byte.is_ascii_hexdigit() }
  })
}

#[cfg(target_os = "macos")]
fn build_reader_browser_url(document_id: &str, configured_origin: Option<&str>) -> Result<url::Url, String> {
  if !valid_uuid_str(document_id) {
    return Err("Invalid Bloom reading document identifier.".into());
  }
  let origin_raw = configured_origin.map(str::trim).filter(|s| !s.is_empty())
    .ok_or_else(|| "Bloom web reader address is not configured.".to_string())?;
  if origin_raw.len() > 512 || origin_raw.chars().any(|c| c.is_control() || c.is_whitespace()) {
    return Err("Invalid Bloom web reader address.".into());
  }
  let origin = url::Url::parse(origin_raw).map_err(|_| "Invalid Bloom web reader address.")?;
  let loopback_http = origin.scheme() == "http" && origin.host().is_some_and(|host| match host {
    url::Host::Domain(domain) => domain == "localhost",
    url::Host::Ipv4(address) => address.is_loopback(),
    url::Host::Ipv6(address) => address.is_loopback(),
  });
  if (origin.scheme() != "https" && !loopback_http)
    || !origin.username().is_empty()
    || origin.password().is_some()
    || origin.host().is_none()
    || origin.path() != "/"
    || origin.query().is_some()
    || origin.fragment().is_some() {
    return Err("Bloom web reader origin must be a clean HTTPS root URL.".into());
  }
  origin.join(&format!("/apps/read/reader/{document_id}"))
    .map_err(|_| "Could not build Bloom web reader address.".into())
}

#[cfg(target_os = "macos")]
#[tauri::command]
fn open_reader_in_browser(document_id: String) -> Result<(), String> {
  let runtime_origin = std::env::var("EXPO_PUBLIC_BLOOM_WEB_URL").ok();
  let configured = option_env!("EXPO_PUBLIC_BLOOM_WEB_URL")
    .or(runtime_origin.as_deref());
  let parsed = build_reader_browser_url(&document_id, configured)?;
  std::process::Command::new("/usr/bin/open")
    .arg(parsed.as_str())
    .spawn()
    .map(|_| ())
    .map_err(|_| "Could not open Bloom in the default web browser.".into())
}

#[cfg(target_os = "macos")]
fn resolve_billing_url(target: &str, configured_origin: Option<&str>) -> Result<url::Url, String> {
  match target {
    "apple_subscriptions" => url::Url::parse("https://apps.apple.com/account/subscriptions")
      .map_err(|_| "Could not build billing address.".to_string()),
    "apple_report_problem" => url::Url::parse("https://reportaproblem.apple.com/")
      .map_err(|_| "Could not build billing address.".to_string()),
    "google_subscriptions" => url::Url::parse("https://play.google.com/store/account/subscriptions")
      .map_err(|_| "Could not build billing address.".to_string()),
    "google_order_history" => url::Url::parse("https://play.google.com/store/account/orderhistory")
      .map_err(|_| "Could not build billing address.".to_string()),
    "google_refund_help" => url::Url::parse("https://support.google.com/googleplay/answer/15574897")
      .map_err(|_| "Could not build billing address.".to_string()),
    "web_subscription" => {
      let origin_raw = configured_origin.map(str::trim).filter(|s| !s.is_empty())
        .ok_or_else(|| "Bloom web billing address is not configured.".to_string())?;
      if origin_raw.len() > 512 || origin_raw.chars().any(|c| c.is_control() || c.is_whitespace()) {
        return Err("Invalid Bloom web billing address.".into());
      }
      let origin = url::Url::parse(origin_raw).map_err(|_| "Invalid Bloom web billing address.")?;
      let loopback_http = origin.scheme() == "http" && origin.host().is_some_and(|host| match host {
        url::Host::Domain(domain) => domain == "localhost",
        url::Host::Ipv4(address) => address.is_loopback(),
        url::Host::Ipv6(address) => address.is_loopback(),
      });
      if (origin.scheme() != "https" && !loopback_http)
        || !origin.username().is_empty()
        || origin.password().is_some()
        || origin.host().is_none()
        || origin.path() != "/"
        || origin.query().is_some()
        || origin.fragment().is_some() {
        return Err("Bloom web billing origin must be a clean HTTPS root URL.".into());
      }
      origin.join("/subscription").map_err(|_| "Could not build Bloom web billing address.".into())
    }
    _ => Err("Unsupported billing destination.".into()),
  }
}

#[cfg(target_os = "macos")]
#[tauri::command]
fn open_billing_url(target: String) -> Result<(), String> {
  let runtime_origin = std::env::var("EXPO_PUBLIC_BLOOM_WEB_URL").ok();
  let configured = option_env!("EXPO_PUBLIC_BLOOM_WEB_URL")
    .or(runtime_origin.as_deref());
  let parsed = resolve_billing_url(&target, configured)?;
  std::process::Command::new("/usr/bin/open")
    .arg(parsed.as_str())
    .spawn()
    .map(|_| ())
    .map_err(|_| "Could not open the billing page in the default web browser.".into())
}

#[cfg(target_os = "macos")]
const KEYCHAIN_SERVICE: &str = "app.bloom.exercise";

#[cfg(target_os = "macos")]
fn validate_keychain_key(key: &str) -> Result<(), String> {
  if key.is_empty()
    || key.len() > 128
    || !key.bytes().all(|b| b.is_ascii_alphanumeric() || matches!(b, b'.' | b'_' | b'-' | b':'))
  {
    return Err("Invalid secure storage key.".into());
  }
  Ok(())
}

#[cfg(target_os = "macos")]
fn encode_hex(value: &str) -> String {
  let mut out = String::with_capacity(value.len() * 2);
  for byte in value.as_bytes() {
    use std::fmt::Write;
    let _ = write!(&mut out, "{byte:02x}");
  }
  out
}

#[cfg(target_os = "macos")]
fn decode_keychain_output(raw: &str) -> Result<String, String> {
  let trimmed = raw.trim();
  if trimmed.is_empty() {
    return Ok(String::new());
  }
  if trimmed.len() % 2 == 0 && trimmed.bytes().all(|b| b.is_ascii_hexdigit()) {
    let mut bytes = Vec::with_capacity(trimmed.len() / 2);
    for pair in trimmed.as_bytes().chunks_exact(2) {
      let hex_pair = std::str::from_utf8(pair).map_err(|_| "Invalid Keychain value.")?;
      let byte = u8::from_str_radix(hex_pair, 16).map_err(|_| "Invalid Keychain value.")?;
      bytes.push(byte);
    }
    if let Ok(text) = String::from_utf8(bytes) {
      return Ok(text);
    }
  }
  Ok(trimmed.to_string())
}

#[cfg(target_os = "macos")]
#[tauri::command]
fn macos_secure_storage_get(key: String) -> Result<Option<String>, String> {
  validate_keychain_key(&key)?;
  let output = std::process::Command::new("/usr/bin/security")
    .args(["find-generic-password", "-s", KEYCHAIN_SERVICE, "-a", &key, "-w"])
    .output()
    .map_err(|_| "Could not access macOS Keychain.")?;
  if !output.status.success() {
    return Ok(None);
  }
  let raw = String::from_utf8(output.stdout).map_err(|_| "Invalid Keychain response.")?;
  decode_keychain_output(&raw).map(Some)
}

#[cfg(target_os = "macos")]
#[tauri::command]
fn macos_secure_storage_set(key: String, value: String) -> Result<(), String> {
  use std::io::Write;
  validate_keychain_key(&key)?;
  if value.len() > 32_768 {
    return Err("Secure storage value exceeds size limit.".into());
  }
  let hex_value = encode_hex(&value);
  let mut child = std::process::Command::new("/usr/bin/security")
    .arg("-i")
    .stdin(std::process::Stdio::piped())
    .stdout(std::process::Stdio::null())
    .stderr(std::process::Stdio::null())
    .spawn()
    .map_err(|_| "Could not access macOS Keychain.")?;
  if let Some(mut stdin) = child.stdin.take() {
    writeln!(
      stdin,
      "add-generic-password -U -s {KEYCHAIN_SERVICE} -a {key} -X {hex_value}"
    )
    .map_err(|_| "Could not write to macOS Keychain.")?;
  }
  let status = child.wait().map_err(|_| "Could not save to macOS Keychain.")?;
  if !status.success() {
    return Err("Could not save to macOS Keychain.".into());
  }
  Ok(())
}

#[cfg(target_os = "macos")]
#[tauri::command]
fn macos_secure_storage_delete(key: String) -> Result<(), String> {
  validate_keychain_key(&key)?;
  let _ = std::process::Command::new("/usr/bin/security")
    .args(["delete-generic-password", "-s", KEYCHAIN_SERVICE, "-a", &key])
    .output()
    .map_err(|_| "Could not remove item from macOS Keychain.")?;
  Ok(())
}

#[cfg(all(test, target_os = "macos"))]
mod reader_browser_tests {
  use super::{build_reader_browser_url, decode_keychain_output, encode_hex, resolve_billing_url, validate_keychain_key};

  const DOC_ID: &str = "7e09a2d3-f94c-47ac-82d6-8b64af1064e1";

  #[test]
  fn accepts_https_and_local_development_origins_for_valid_document_id() {
    let prod = build_reader_browser_url(DOC_ID, Some("https://bloom.example/")).unwrap();
    assert_eq!(prod.as_str(), format!("https://bloom.example/apps/read/reader/{DOC_ID}"));
    let dev = build_reader_browser_url(DOC_ID, Some("http://localhost:8081")).unwrap();
    assert_eq!(dev.as_str(), format!("http://localhost:8081/apps/read/reader/{DOC_ID}"));
  }

  #[test]
  fn rejects_invalid_document_ids_and_untrusted_origins() {
    assert!(build_reader_browser_url("../settings", Some("https://bloom.example")).is_err());
    assert!(build_reader_browser_url("", Some("https://bloom.example")).is_err());
    assert!(build_reader_browser_url(DOC_ID, None).is_err());
    assert!(build_reader_browser_url(DOC_ID, Some("http://bloom.example")).is_err());
    assert!(build_reader_browser_url(DOC_ID, Some("https://user@bloom.example")).is_err());
    assert!(build_reader_browser_url(DOC_ID, Some("https://bloom.example/subpath")).is_err());
    assert!(build_reader_browser_url(DOC_ID, Some("file:///etc/passwd")).is_err());
  }

  #[test]
  fn validates_keychain_keys_and_hex_roundtrip() {
    assert!(validate_keychain_key("bloom.child.refresh.v1").is_ok());
    assert!(validate_keychain_key("sb-project-auth-token:chunk:0").is_ok());
    assert!(validate_keychain_key("").is_err());
    assert!(validate_keychain_key("bad key with spaces").is_err());
    assert!(validate_keychain_key("bad\nkey").is_err());
    let encoded = encode_hex("{\"refresh_token\":\"secret-123\"}");
    assert_eq!(decode_keychain_output(&encoded).unwrap(), "{\"refresh_token\":\"secret-123\"}");
  }

  #[test]
  fn allowlists_billing_destinations_and_rejects_arbitrary_targets() {
    assert_eq!(
      resolve_billing_url("apple_subscriptions", None).unwrap().as_str(),
      "https://apps.apple.com/account/subscriptions"
    );
    assert_eq!(
      resolve_billing_url("web_subscription", Some("https://bloom.example/")).unwrap().as_str(),
      "https://bloom.example/subscription"
    );
    assert!(resolve_billing_url("https://evil.example/", None).is_err());
    assert!(resolve_billing_url("web_subscription", None).is_err());
    assert!(resolve_billing_url("web_subscription", Some("http://bloom.example")).is_err());
  }
}

#[cfg(all(test, target_os = "macos"))]
mod deep_link_tests {
  use super::route_from_deep_link;

  #[test]
  fn accepts_bloom_focus_deep_links() {
    let earned = url::Url::parse("bloomexercise://focus?section=earned").unwrap();
    assert_eq!(route_from_deep_link(&earned).as_deref(), Some("/focus?section=earned"));

    let plain = url::Url::parse("bloomexercise://focus").unwrap();
    assert_eq!(route_from_deep_link(&plain).as_deref(), Some("/focus"));

    let slash_path = url::Url::parse("bloomexercise:///focus?section=websites").unwrap();
    assert_eq!(route_from_deep_link(&slash_path).as_deref(), Some("/focus?section=websites"));
  }

  #[test]
  fn rejects_unknown_schemes_and_sections() {
    let other = url::Url::parse("https://focus?section=earned").unwrap();
    assert_eq!(route_from_deep_link(&other), None);

    let unknown_host = url::Url::parse("bloomexercise://settings?section=earned").unwrap();
    assert_eq!(route_from_deep_link(&unknown_host), None);

    let bad_section = url::Url::parse("bloomexercise://focus?section=admin").unwrap();
    assert_eq!(route_from_deep_link(&bad_section).as_deref(), Some("/focus"));
  }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
  let builder = tauri::Builder::default();
  #[cfg(target_os = "macos")]
  let builder = builder
    .manage(PendingDeepLink(std::sync::Mutex::new(None)))
    .invoke_handler(tauri::generate_handler![
      macos_blocking_status,
      macos_manage_website_rules,
      macos_manage_app_rules,
      macos_credit_session,
      macos_usage_session,
      macos_secure_storage_get,
      macos_secure_storage_set,
      macos_secure_storage_delete,
      open_reader_in_browser,
      open_billing_url,
      take_pending_deep_link
    ])
    .on_window_event(|window, event| {
      if window.label() == "main" {
        if let tauri::WindowEvent::CloseRequested { api, .. } = event {
          // Keep the signed-in renderer alive for rule synchronization. A
          // normal application Quit remains available from the macOS menu.
          if window.hide().is_ok() { api.prevent_close(); }
        }
      }
    });
  #[cfg(target_os = "macos")]
  {
    use tauri::{Emitter, Manager};
    builder.build(tauri::generate_context!()).expect("failed to build Bloom")
      .run(|app, event| {
        match event {
          tauri::RunEvent::Reopen { has_visible_windows: false, .. } => {
            if let Some(window) = app.get_webview_window("main") {
              let _ = window.show();
              let _ = window.set_focus();
            }
          }
          tauri::RunEvent::Opened { urls } => {
            if let Some(route) = urls.iter().find_map(route_from_deep_link) {
              if let Ok(mut pending) = app.state::<PendingDeepLink>().0.lock() {
                *pending = Some(route.clone());
              }
              if let Some(window) = app.get_webview_window("main") {
                let _ = window.unminimize();
                let _ = window.show();
                let _ = window.set_focus();
              }
              let _ = app.emit("bloom-deep-link", route);
            }
          }
          _ => {}
        }
      });
  }
  #[cfg(not(target_os = "macos"))]
  builder
    .run(tauri::generate_context!())
    .expect("failed to run Bloom");
}
