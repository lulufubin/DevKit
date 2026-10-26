use devkit_core::json;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum JsonMode {
    Strict,
    Lenient,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum JsonDiffKind {
    Added,
    Removed,
    Changed,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct JsonDiffOp {
    pub path: String,
    pub kind: JsonDiffKind,
    pub left: Option<String>,
    pub right: Option<String>,
}

fn to_mode(mode: JsonMode) -> json::ParseMode {
    match mode {
        JsonMode::Strict => json::ParseMode::Strict,
        JsonMode::Lenient => json::ParseMode::Lenient,
    }
}

pub fn json_format(text: String, mode: JsonMode) -> Result<String, String> {
    json::format(&text, to_mode(mode))
}

pub fn json_minify(text: String, mode: JsonMode) -> Result<String, String> {
    json::minify(&text, to_mode(mode))
}

pub fn json_diff(left: String, right: String, mode: JsonMode) -> Result<Vec<JsonDiffOp>, String> {
    let ops = json::diff(&left, &right, to_mode(mode))?;
    Ok(ops
        .into_iter()
        .map(|op| JsonDiffOp {
            path: op.path,
            kind: match op.kind {
                json::DiffKind::Added => JsonDiffKind::Added,
                json::DiffKind::Removed => JsonDiffKind::Removed,
                json::DiffKind::Changed => JsonDiffKind::Changed,
            },
            left: op.left,
            right: op.right,
        })
        .collect())
}
