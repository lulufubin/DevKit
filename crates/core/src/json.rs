pub const MAX_TEXT_BYTES: usize = 20 * 1024 * 1024;

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum DiffKind {
    Added,
    Removed,
    Changed,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DiffOp {
    pub path: String,
    pub kind: DiffKind,
    pub left: Option<String>,
    pub right: Option<String>,
}

pub fn format(text: &str) -> Result<String, String> {
    let value = parse_json(text)?;
    serde_json::to_string_pretty(&value).map_err(|e| e.to_string())
}

pub fn minify(text: &str) -> Result<String, String> {
    let value = parse_json(text)?;
    serde_json::to_string(&value).map_err(|e| e.to_string())
}

pub fn diff(left: &str, right: &str) -> Result<Vec<DiffOp>, String> {
    let left_value = parse_json(left)?;
    let right_value = parse_json(right)?;
    let mut ops = Vec::new();
    walk_diff("$", &left_value, &right_value, &mut ops);
    Ok(ops)
}

fn parse_json(text: &str) -> Result<serde_json::Value, String> {
    ensure_size_limit(text, MAX_TEXT_BYTES)?;
    serde_json::from_str(text).map_err(|err| format!("{} (行 {}, 列 {})", err, err.line(), err.column()))
}

pub fn ensure_size_limit(text: &str, max: usize) -> Result<(), String> {
    if text.len() > max {
        return Err(format!("文本超过 {} 字节上限", max));
    }
    Ok(())
}

fn walk_diff(path: &str, left: &serde_json::Value, right: &serde_json::Value, ops: &mut Vec<DiffOp>) {
    if left == right {
        return;
    }
    match (left, right) {
        (serde_json::Value::Object(l_map), serde_json::Value::Object(r_map)) => {
            let mut keys: Vec<&String> = l_map.keys().chain(r_map.keys()).collect();
            keys.sort();
            keys.dedup();
            for key in keys {
                let child = format!("{path}.{key}");
                match (l_map.get(key), r_map.get(key)) {
                    (Some(lv), Some(rv)) => walk_diff(&child, lv, rv, ops),
                    (None, Some(rv)) => ops.push(DiffOp {
                        path: child,
                        kind: DiffKind::Added,
                        left: None,
                        right: Some(compact(rv)),
                    }),
                    (Some(lv), None) => ops.push(DiffOp {
                        path: child,
                        kind: DiffKind::Removed,
                        left: Some(compact(lv)),
                        right: None,
                    }),
                    (None, None) => {}
                }
            }
        }
        (serde_json::Value::Array(l_arr), serde_json::Value::Array(r_arr)) => {
            let max = l_arr.len().max(r_arr.len());
            for i in 0..max {
                let child = format!("{path}[{i}]");
                match (l_arr.get(i), r_arr.get(i)) {
                    (Some(lv), Some(rv)) => walk_diff(&child, lv, rv, ops),
                    (None, Some(rv)) => ops.push(DiffOp {
                        path: child,
                        kind: DiffKind::Added,
                        left: None,
                        right: Some(compact(rv)),
                    }),
                    (Some(lv), None) => ops.push(DiffOp {
                        path: child,
                        kind: DiffKind::Removed,
                        left: Some(compact(lv)),
                        right: None,
                    }),
                    (None, None) => {}
                }
            }
        }
        _ => ops.push(DiffOp {
            path: path.to_string(),
            kind: DiffKind::Changed,
            left: Some(compact(left)),
            right: Some(compact(right)),
        }),
    }
}

fn compact(value: &serde_json::Value) -> String {
    serde_json::to_string(value).unwrap_or_else(|_| value.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn format_pretty_prints_object() {
        let out = format("{\"b\":2,\"a\":1}").unwrap();
        assert!(out.contains('\n'));
        assert!(out.contains("\"a\": 1"));
    }

    #[test]
    fn minify_removes_whitespace() {
        assert_eq!(minify("{\n  \"a\": 1\n}").unwrap(), "{\"a\":1}");
    }

    #[test]
    fn invalid_json_includes_line_and_column() {
        let err = format("{").unwrap_err();
        assert!(err.contains("行"));
        assert!(err.contains("列"));
    }

    #[test]
    fn size_limit_rejects_oversized_text() {
        assert!(ensure_size_limit("hello", 3).unwrap_err().contains("上限"));
    }

    #[test]
    fn diff_reports_added_removed_changed() {
        let ops = diff(
            r#"{"keep":1,"gone":2,"edit":"old"}"#,
            r#"{"keep":1,"new":3,"edit":"fresh"}"#,
        )
        .unwrap();
        assert!(ops.iter().any(|o| o.path == "$.gone" && o.kind == DiffKind::Removed));
        assert!(ops.iter().any(|o| o.path == "$.new" && o.kind == DiffKind::Added));
        assert!(ops.iter().any(|o| o.path == "$.edit" && o.kind == DiffKind::Changed));
    }
}
