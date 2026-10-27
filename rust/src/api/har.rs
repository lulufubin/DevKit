use devkit_core::har as core;

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
    pub http_version: String,
    pub status_text: String,
    pub request_headers: Vec<HarHeader>,
    pub response_headers: Vec<HarHeader>,
    pub cookies: Vec<HarHeader>,
    pub query: Vec<HarHeader>,
    pub request_body: String,
    pub response_body: String,
    pub request_mime: String,
    pub response_mime: String,
    pub request_raw: String,
    pub response_raw: String,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum HarExportFormat {
    Har,
    Json,
}

#[derive(Clone, Debug, PartialEq)]
pub struct HarFilter {
    pub url_contains: String,
    pub method: String,
    pub status: String,
    pub max_time_ms: Option<f64>,
}

pub fn har_import_text(text: String) -> Result<Vec<HarEntrySummary>, String> {
    Ok(core::har_import_text(&text)?.into_iter().map(summary).collect())
}

pub fn har_import_path(path: String) -> Result<Vec<HarEntrySummary>, String> {
    Ok(core::har_import_path(&path)?.into_iter().map(summary).collect())
}

pub fn har_filter(filter: HarFilter) -> Result<Vec<HarEntrySummary>, String> {
    let core_filter = core::HarFilter {
        url_contains: empty_to_none(&filter.url_contains),
        method: empty_to_none(&filter.method),
        status: empty_to_none(&filter.status),
        max_time_ms: filter.max_time_ms,
    };
    Ok(core::har_filter(core_filter)?.into_iter().map(summary).collect())
}

pub fn har_entry(id: String) -> Result<HarEntryDetail, String> {
    Ok(detail(core::har_entry(&id)?))
}

pub fn har_export(ids: Vec<String>, format: HarExportFormat) -> Result<String, String> {
    let format = match format {
        HarExportFormat::Har => core::HarExportFormat::Har,
        HarExportFormat::Json => core::HarExportFormat::Json,
    };
    core::har_export(ids, format)
}

pub fn har_to_python(id: String) -> Result<String, String> {
    core::har_to_python(&id)
}

fn empty_to_none(value: &str) -> Option<String> {
    let trimmed = value.trim();
    if trimmed.is_empty() {
        None
    } else {
        Some(trimmed.to_string())
    }
}

fn summary(item: core::HarEntrySummary) -> HarEntrySummary {
    HarEntrySummary {
        id: item.id,
        method: item.method,
        url: item.url,
        status: item.status,
        time_ms: item.time_ms,
        size: item.size,
    }
}

fn header(item: core::HarHeader) -> HarHeader {
    HarHeader {
        name: item.name,
        value: item.value,
    }
}

fn detail(item: core::HarEntryDetail) -> HarEntryDetail {
    HarEntryDetail {
        id: item.id,
        method: item.method,
        url: item.url,
        status: item.status,
        time_ms: item.time_ms,
        size: item.size,
        http_version: item.http_version,
        status_text: item.status_text,
        request_headers: item.request_headers.into_iter().map(header).collect(),
        response_headers: item.response_headers.into_iter().map(header).collect(),
        cookies: item.cookies.into_iter().map(header).collect(),
        query: item.query.into_iter().map(header).collect(),
        request_body: item.request_body.unwrap_or_default(),
        response_body: item.response_body.unwrap_or_default(),
        request_mime: item.request_mime.unwrap_or_default(),
        response_mime: item.response_mime.unwrap_or_default(),
        request_raw: item.request_raw,
        response_raw: item.response_raw,
    }
}
