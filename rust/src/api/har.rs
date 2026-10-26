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
    pub request_headers: Vec<HarHeader>,
    pub response_headers: Vec<HarHeader>,
    pub request_body: String,
    pub response_body: String,
    pub mime_type: String,
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

fn detail(item: core::HarEntryDetail) -> HarEntryDetail {
    HarEntryDetail {
        id: item.id,
        method: item.method,
        url: item.url,
        status: item.status,
        time_ms: item.time_ms,
        request_headers: item
            .request_headers
            .into_iter()
            .map(|h| HarHeader {
                name: h.name,
                value: h.value,
            })
            .collect(),
        response_headers: item
            .response_headers
            .into_iter()
            .map(|h| HarHeader {
                name: h.name,
                value: h.value,
            })
            .collect(),
        request_body: item.request_body.unwrap_or_default(),
        response_body: item.response_body.unwrap_or_default(),
        mime_type: item.response_mime.unwrap_or_default(),
    }
}
