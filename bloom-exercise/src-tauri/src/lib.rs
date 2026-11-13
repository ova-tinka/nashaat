#[cfg(target_os = "macos")]
#[tauri::command]
async fn macos_filter(action: String, domains: Option<Vec<String>>, apps: Option<Vec<String>>, timing: Option<serde_json::Value>, targets: Option<serde_json::Value>, usage: Option<serde_json::Value>, account_id: Option<String>) -> Result<serde_json::Value, String> {
  if !matches!(action.as_str(), "activate" | "start" | "stop" | "clearManualDomains" | "cleanupHosts" | "hostsRecoveryStatus" | "hostsPolicyStatus" | "syncHostsManaged" | "enrollHosts" | "startHostsUsage" | "stopHostsUsage" | "clearManualApps" | "status" | "appStatus" | "clock" | "startCreditAccess" | "endCreditAccess" | "activateApps" | "chooseApp" | "listInstalledApps" | "startApps" | "stopApps" | "getUsageAccess" | "startUsageAccess" | "closeUsageAccess" | "clearUsageAccess" | "openAccessibilitySettings" | "syncManagedRules") {
    return Err("Invalid filter action.".into());
  }
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
      "sessionId": session_id, "userId": user_id, "accountId": account_id }))
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

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
  let builder = tauri::Builder::default();
  #[cfg(target_os = "macos")]
  let builder = builder.invoke_handler(tauri::generate_handler![macos_filter])
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
    use tauri::Manager;
    builder.build(tauri::generate_context!()).expect("failed to build Bloom Exercise")
      .run(|app, event| {
        if let tauri::RunEvent::Reopen { has_visible_windows: false, .. } = event {
          if let Some(window) = app.get_webview_window("main") {
            let _ = window.show();
            let _ = window.set_focus();
          }
        }
      });
  }
  #[cfg(not(target_os = "macos"))]
  builder
    .run(tauri::generate_context!())
    .expect("failed to run Bloom Exercise");
}
