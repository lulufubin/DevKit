//! HAR 1.2 import, filter, detail, export, and Python `requests` generation.

use std::sync::{Mutex, MutexGuard};

use serde::Deserialize;
use serde_json::{json, Value};

#[derive(Clone, Debug, PartialEq)]
pub struct HarEntrySummary {
    pub id: String,
    pub method: String,
    pub url: String,
    pub status: i32,
    pub time_ms: f64,
    pub size: i64,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct HarHeader {
    pub name: String,
    pub value: String,
}

#[derive(Clone, Debug, PartialEq)]
pub struct HarEntryDetail {
    pub id: String,
    pub method: String,
    pub url: String,
    pub status: i32,
    pub time_ms: f64,
    pub size: i64,
    pub request_headers: Vec<HarHeader>,
    pub response_headers: Vec<HarHeader>,
    pub request_body: Option<String>,
    pub response_body: Option<String>,
    pub request_mime: Option<String>,
    pub response_mime: Option<String>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum HarExportFormat {
    Har,
    Json,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct HarFilter {
    pub url_contains: Option<String>,
    pub method: Option<String>,
    pub status: Option<String>,
    pub max_time_ms: Option<f64>,
}

#[derive(Clone, Debug)]
struct StoredEntry {
    id: String,
    summary: HarEntrySummary,
    raw: Value,
}

#[derive(Default)]
struct HarStore {
    entries: Vec<StoredEntry>,
}

#[derive(Deserialize)]
struct HarFile {
    log: HarLog,
}

#[derive(Deserialize)]
struct HarLog {
    entries: Vec<Value>,
}

static STORE: Mutex<HarStore> = Mutex::new(HarStore {
    entries: Vec::new(),
});

pub fn har_import_text(text: &str) -> Result<Vec<HarEntrySummary>, String> {
    let parsed: HarFile = serde_json::from_str(text).map_err(|err| {
        format!("无法解析 HAR: {} (行 {}, 列 {})", err, err.line(), err.column())
    })?;
    let mut store = lock_store()?;
    store.entries = parsed
        .log
        .entries
        .into_iter()
        .enumerate()
        .map(|(idx, raw)| {
            let id = idx.to_string();
            let summary = summary_from_entry(id.clone(), &raw);
            StoredEntry { id, summary, raw }
        })
        .collect();
    Ok(store.entries.iter().map(|entry| entry.summary.clone()).collect())
}

pub fn har_import_path(path: &str) -> Result<Vec<HarEntrySummary>, String> {
    let text = std::fs::read_to_string(path).map_err(|err| err.to_string())?;
    har_import_text(&text)
}

pub fn har_filter(filter: HarFilter) -> Result<Vec<HarEntrySummary>, String> {
    let store = lock_store()?;
    Ok(store
        .entries
        .iter()
        .filter(|entry| matches_filter(&entry.summary, &filter))
        .map(|entry| entry.summary.clone())
        .collect())
}

pub fn har_entry(id: &str) -> Result<HarEntryDetail, String> {
    let store = lock_store()?;
    let entry = store
        .entries
        .iter()
        .find(|entry| entry.id == id)
        .ok_or_else(|| format!("未找到 HAR 条目: {id}"))?;
    Ok(detail_from_entry(entry))
}

pub fn har_export(ids: Vec<String>, format: HarExportFormat) -> Result<String, String> {
    let store = lock_store()?;
    let entries: Vec<&Value> = if ids.is_empty() {
        store.entries.iter().map(|entry| &entry.raw).collect()
    } else {
        ids.iter()
            .map(|id| {
                store
                    .entries
                    .iter()
                    .find(|entry| entry.id == *id)
                    .map(|entry| &entry.raw)
                    .ok_or_else(|| format!("未找到 HAR 条目: {id}"))
            })
            .collect::<Result<Vec<_>, _>>()?
    };
    match format {
        HarExportFormat::Har => serde_json::to_string_pretty(&json!({
            "log": {
                "version": "1.2",
                "creator": { "name": "DevKit", "version": "0.1.0" },
                "entries": entries,
            }
        }))
        .map_err(|err| err.to_string()),
        HarExportFormat::Json => serde_json::to_string_pretty(&entries).map_err(|err| err.to_string()),
    }
}

pub fn har_to_python(id: &str) -> Result<String, String> {
    let store = lock_store()?;
    let entry = store
        .entries
        .iter()
        .find(|entry| entry.id == id)
        .ok_or_else(|| format!("未找到 HAR 条目: {id}"))?;
    Ok(python_from_entry(&entry.raw, &entry.summary))
}

fn lock_store() -> Result<MutexGuard<'static, HarStore>, String> {
    STORE
        .lock()
        .map_err(|_| "HAR 存储锁已损坏".to_string())
}

fn summary_from_entry(id: String, entry: &Value) -> HarEntrySummary {
    let request = entry.get("request").cloned().unwrap_or(Value::Null);
    let response = entry.get("response").cloned().unwrap_or(Value::Null);
    let method = string_field(&request, "method");
    let url = string_field(&request, "url");
    let status = response
        .get("status")
        .and_then(Value::as_i64)
        .unwrap_or(0) as i32;
    let time_ms = entry.get("time").and_then(Value::as_f64).unwrap_or(0.0);
    let size = response
        .pointer("/content/size")
        .and_then(Value::as_i64)
        .or_else(|| response.get("bodySize").and_then(Value::as_i64))
        .unwrap_or(0);
    HarEntrySummary {
        id,
        method,
        url,
        status,
        time_ms,
        size,
    }
}

fn detail_from_entry(entry: &StoredEntry) -> HarEntryDetail {
    let request = entry.raw.get("request").cloned().unwrap_or(Value::Null);
    let response = entry.raw.get("response").cloned().unwrap_or(Value::Null);
    let request_headers = parse_headers(request.get("headers"));
    let response_headers = parse_headers(response.get("headers"));
    let request_mime = request
        .pointer("/postData/mimeType")
        .and_then(Value::as_str)
        .map(ToOwned::to_owned);
    let response_mime = response
        .pointer("/content/mimeType")
        .and_then(Value::as_str)
        .map(ToOwned::to_owned);
    let request_body = request
        .pointer("/postData/text")
        .and_then(Value::as_str)
        .map(ToOwned::to_owned);
    let response_body = decode_content_text(response.get("content"));
    HarEntryDetail {
        id: entry.summary.id.clone(),
        method: entry.summary.method.clone(),
        url: entry.summary.url.clone(),
        status: entry.summary.status,
        time_ms: entry.summary.time_ms,
        size: entry.summary.size,
        request_headers,
        response_headers,
        request_body,
        response_body,
        request_mime,
        response_mime,
    }
}

fn decode_content_text(content: Option<&Value>) -> Option<String> {
    let content = content?;
    let text = content.get("text")?.as_str()?;
    let encoding = content
        .get("encoding")
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_ascii_lowercase();
    if encoding == "base64" {
        use base64::engine::general_purpose::STANDARD;
        use base64::Engine;
        STANDARD
            .decode(text.trim())
            .ok()
            .and_then(|bytes| String::from_utf8(bytes).ok())
            .or_else(|| Some(text.to_string()))
    } else {
        Some(text.to_string())
    }
}

fn parse_headers(value: Option<&Value>) -> Vec<HarHeader> {
    value
        .and_then(Value::as_array)
        .map(|items| {
            items
                .iter()
                .filter_map(|item| {
                    Some(HarHeader {
                        name: item.get("name")?.as_str()?.to_string(),
                        value: item.get("value").and_then(Value::as_str).unwrap_or("").to_string(),
                    })
                })
                .collect()
        })
        .unwrap_or_default()
}

fn string_field(value: &Value, key: &str) -> String {
    value
        .get(key)
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string()
}

fn matches_filter(summary: &HarEntrySummary, filter: &HarFilter) -> bool {
    if let Some(needle) = filter.url_contains.as_deref().filter(|s| !s.is_empty()) {
        if !summary.url.contains(needle) {
            return false;
        }
    }
    if let Some(method) = filter.method.as_deref().filter(|s| !s.is_empty()) {
        if !summary.method.eq_ignore_ascii_case(method) {
            return false;
        }
    }
    if let Some(status) = filter.status.as_deref().filter(|s| !s.is_empty()) {
        if !status_matches(summary.status, status) {
            return false;
        }
    }
    if let Some(max_time) = filter.max_time_ms {
        if summary.time_ms > max_time {
            return false;
        }
    }
    true
}

fn status_matches(status: i32, filter: &str) -> bool {
    let trimmed = filter.trim();
    let lower = trimmed.to_ascii_lowercase();
    let bytes = lower.as_bytes();
    if bytes.len() == 3 && bytes[1] == b'x' && bytes[2] == b'x' && bytes[0].is_ascii_digit() {
        let class = (bytes[0] - b'0') as i32;
        let lo = class * 100;
        return status >= lo && status < lo + 100;
    }
    trimmed.parse::<i32>().ok() == Some(status)
}

fn python_from_entry(raw: &Value, summary: &HarEntrySummary) -> String {
    let request = raw.get("request").cloned().unwrap_or(Value::Null);
    let headers = parse_headers(request.get("headers"));
    let cookies = parse_cookies(&request, &headers);
    let mime = request
        .pointer("/postData/mimeType")
        .and_then(Value::as_str)
        .or_else(|| {
            headers.iter().find_map(|header| {
                header
                    .name
                    .eq_ignore_ascii_case("content-type")
                    .then_some(header.value.as_str())
            })
        })
        .unwrap_or("");
    let body = request
        .pointer("/postData/text")
        .and_then(Value::as_str);
    let json_body = body.filter(|_| is_json_mime(mime));

    let mut out = String::new();
    if json_body.is_some() {
        out.push_str("import json\n");
    }
    out.push_str("import requests\n\n");

    if !cookies.is_empty() {
        out.push_str("cookies = {\n");
        for (name, value) in &cookies {
            out.push_str(&format!("    {}: {},\n", py_str(name), py_str(value)));
        }
        out.push_str("}\n\n");
    }

    out.push_str("headers = {\n");
    for header in &headers {
        if header.name.eq_ignore_ascii_case("cookie") {
            continue;
        }
        out.push_str(&format!(
            "    {}: {},\n",
            py_str(&header.name),
            py_str(&header.value)
        ));
    }
    out.push_str("}\n\n");

    if let Some(text) = json_body {
        out.push_str(&format!("json_body = json.loads({})\n", py_str(text)));
    } else if let Some(text) = body {
        out.push_str(&format!("data = {}\n", py_str(text)));
    }

    out.push_str("response = requests.request(\n");
    out.push_str(&format!("    {},\n", py_str(&summary.method)));
    out.push_str(&format!("    {},\n", py_str(&summary.url)));
    out.push_str("    headers=headers,\n");
    if !cookies.is_empty() {
        out.push_str("    cookies=cookies,\n");
    }
    if json_body.is_some() {
        out.push_str("    json=json_body,\n");
    } else if body.is_some() {
        out.push_str("    data=data,\n");
    }
    out.push_str(")\n");
    out
}

fn parse_cookies(request: &Value, headers: &[HarHeader]) -> Vec<(String, String)> {
    if let Some(items) = request.get("cookies").and_then(Value::as_array) {
        let parsed: Vec<(String, String)> = items
            .iter()
            .filter_map(|item| {
                Some((
                    item.get("name")?.as_str()?.to_string(),
                    item.get("value").and_then(Value::as_str).unwrap_or("").to_string(),
                ))
            })
            .collect();
        if !parsed.is_empty() {
            return parsed;
        }
    }
    headers
        .iter()
        .find(|header| header.name.eq_ignore_ascii_case("cookie"))
        .map(|header| {
            header
                .value
                .split(';')
                .filter_map(|part| {
                    let (name, value) = part.split_once('=')?;
                    Some((name.trim().to_string(), value.trim().to_string()))
                })
                .collect()
        })
        .unwrap_or_default()
}

fn is_json_mime(mime: &str) -> bool {
    mime.to_ascii_lowercase().contains("json")
}

fn py_str(value: &str) -> String {
    let mut out = String::from("'");
    for ch in value.chars() {
        match ch {
            '\\' => out.push_str("\\\\"),
            '\'' => out.push_str("\\'"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            _ => out.push(ch),
        }
    }
    out.push('\'');
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::json::MAX_TEXT_BYTES;

    static TEST_LOCK: Mutex<()> = Mutex::new(());

    const SAMPLE_HAR: &str = r#"{
      "log": {
        "version": "1.2",
        "creator": {"name": "fixture", "version": "1"},
        "entries": [
          {
            "startedDateTime": "2024-01-01T00:00:00.000Z",
            "time": 120,
            "request": {
              "method": "POST",
              "url": "https://example.com/api/users",
              "httpVersion": "HTTP/1.1",
              "cookies": [{"name": "session", "value": "abc"}],
              "headers": [
                {"name": "Content-Type", "value": "application/json"},
                {"name": "Cookie", "value": "session=abc"}
              ],
              "queryString": [],
              "postData": {
                "mimeType": "application/json",
                "text": "{\"name\":\"ada\"}"
              },
              "headersSize": -1,
              "bodySize": 15
            },
            "response": {
              "status": 201,
              "statusText": "Created",
              "httpVersion": "HTTP/1.1",
              "cookies": [],
              "headers": [{"name": "Content-Type", "value": "application/json"}],
              "content": {"size": 11, "mimeType": "application/json", "text": "{\"ok\":true}"},
              "redirectURL": "",
              "headersSize": -1,
              "bodySize": 11
            },
            "cache": {},
            "timings": {"send": 10, "wait": 100, "receive": 10}
          },
          {
            "startedDateTime": "2024-01-01T00:00:01.000Z",
            "time": 50,
            "request": {
              "method": "GET",
              "url": "https://example.com/health",
              "httpVersion": "HTTP/1.1",
              "cookies": [],
              "headers": [],
              "queryString": [],
              "headersSize": -1,
              "bodySize": 0
            },
            "response": {
              "status": 200,
              "statusText": "OK",
              "httpVersion": "HTTP/1.1",
              "cookies": [],
              "headers": [],
              "content": {"size": 2, "mimeType": "text/plain", "text": "ok"},
              "redirectURL": "",
              "headersSize": -1,
              "bodySize": 2
            },
            "cache": {},
            "timings": {"send": 1, "wait": 48, "receive": 1}
          }
        ]
      }
    }"#;

    #[test]
    fn import_sample_har() {
        let _guard = TEST_LOCK.lock().unwrap_or_else(|err| err.into_inner());
        let rows = har_import_text(SAMPLE_HAR).unwrap();
        assert_eq!(rows.len(), 2);
        assert_eq!(rows[0].method, "POST");
        assert_eq!(rows[0].status, 201);
        assert_eq!(rows[1].url, "https://example.com/health");
    }

    #[test]
    fn filter_sample_har() {
        let _guard = TEST_LOCK.lock().unwrap_or_else(|err| err.into_inner());
        har_import_text(SAMPLE_HAR).unwrap();
        let rows = har_filter(HarFilter {
            url_contains: Some("health".into()),
            method: Some("GET".into()),
            status: Some("2xx".into()),
            max_time_ms: Some(100.0),
        })
        .unwrap();
        assert_eq!(rows.len(), 1);
        assert_eq!(rows[0].id, "1");
    }

    #[test]
    fn export_sample_har() {
        let _guard = TEST_LOCK.lock().unwrap_or_else(|err| err.into_inner());
        har_import_text(SAMPLE_HAR).unwrap();
        let har = har_export(Vec::new(), HarExportFormat::Har).unwrap();
        assert!(har.contains("\"log\""));
        assert!(har.contains("https://example.com/api/users"));
        let json = har_export(Vec::new(), HarExportFormat::Json).unwrap();
        assert!(json.contains("https://example.com/health"));
    }

    #[test]
    fn python_contains_requests_and_json_loads() {
        let _guard = TEST_LOCK.lock().unwrap_or_else(|err| err.into_inner());
        har_import_text(SAMPLE_HAR).unwrap();
        let py = har_to_python("0").unwrap();
        assert!(py.contains("requests"));
        assert!(py.contains("json.loads"));
        assert!(!py.contains("'Cookie'"));
        assert!(py.contains("cookies"));
    }

    #[test]
    fn missing_entry_is_an_error() {
        let _guard = TEST_LOCK.lock().unwrap_or_else(|err| err.into_inner());
        har_import_text(SAMPLE_HAR).unwrap();
        let err = har_entry("missing").unwrap_err();
        assert!(err.contains("未找到"));
        assert!(har_to_python("999").is_err());
    }

    #[test]
    fn import_har_larger_than_text_cap() {
        let _guard = TEST_LOCK.lock().unwrap_or_else(|err| err.into_inner());
        let pad = " ".repeat(MAX_TEXT_BYTES + 1);
        let text = format!(
            r#"{{"log":{{"version":"1.2","creator":{{"name":"x","version":"1"}},"comment":"{pad}","entries":[]}}}}"#
        );
        assert!(text.len() > MAX_TEXT_BYTES);
        let rows = har_import_text(&text).unwrap();
        assert!(rows.is_empty());
    }
}
