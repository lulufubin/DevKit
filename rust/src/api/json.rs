use devkit_core::json;

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

pub fn json_format(text: String) -> Result<String, String> {
    json::format(&text)
}

pub fn json_minify(text: String) -> Result<String, String> {
    json::minify(&text)
}

pub fn json_diff(left: String, right: String) -> Result<Vec<JsonDiffOp>, String> {
    let ops = json::diff(&left, &right)?;
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
