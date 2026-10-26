use std::fs;
use std::io::Cursor;
use std::path::{Path, PathBuf};

use resvg::usvg::{self, Tree};
use tiny_skia::{Pixmap, Transform};

fn main() {
    if let Err(error) = run() {
        eprintln!("{error}");
        std::process::exit(1);
    }
}

fn run() -> Result<(), String> {
    let root = workspace_root();
    let svg_path = root.join("logo/devkit-logo-light.svg");
    let svg = fs::read(&svg_path).map_err(|e| format!("读取 {}: {e}", svg_path.display()))?;
    let tree = Tree::from_data(&svg, &usvg::Options::default())
        .map_err(|e| format!("解析 SVG: {e}"))?;

    let mut ico = ico::IconDir::new(ico::ResourceType::Icon);
    for size in [16_u32, 32, 48, 256] {
        let pixmap = render(&tree, size)?;
        let png = encode_png(&pixmap)?;
        let image = ico::IconImage::read_png(Cursor::new(png))
            .map_err(|e| format!("编码 {size} ICO 帧: {e}"))?;
        ico.add_entry(
            ico::IconDirEntry::encode(&image).map_err(|e| format!("写入 {size} ICO 帧: {e}"))?,
        );
    }
    let ico_path = root.join("windows/runner/resources/app_icon.ico");
    let mut ico_file =
        fs::File::create(&ico_path).map_err(|e| format!("创建 {}: {e}", ico_path.display()))?;
    ico.write(&mut ico_file)
        .map_err(|e| format!("写 ICO: {e}"))?;

    for size in [16_u32, 32, 64, 128, 256, 512, 1024] {
        write_png(
            &tree,
            size,
            &root.join(format!(
                "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{size}.png"
            )),
        )?;
    }

    write_png(
        &tree,
        512,
        &root.join("linux/runner/resources/app_icon.png"),
    )?;
    for size in [16_u32, 32, 48, 256, 512] {
        write_png(
            &tree,
            size,
            &root.join(format!("linux/hicolor/{size}x{size}/apps/devkit.png")),
        )?;
    }
    Ok(())
}

fn workspace_root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../..")
}

fn render(tree: &Tree, size: u32) -> Result<Pixmap, String> {
    let mut pixmap =
        Pixmap::new(size, size).ok_or_else(|| format!("无法创建 {size}x{size} 画布"))?;
    let tree_size = tree.size();
    let scale = (size as f32 / tree_size.width()).min(size as f32 / tree_size.height());
    resvg::render(tree, Transform::from_scale(scale, scale), &mut pixmap.as_mut());
    Ok(pixmap)
}

fn encode_png(pixmap: &Pixmap) -> Result<Vec<u8>, String> {
    pixmap
        .encode_png()
        .map_err(|e| format!("编码 PNG: {e}"))
}

fn write_png(tree: &Tree, size: u32, path: &Path) -> Result<(), String> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|e| format!("创建 {}: {e}", parent.display()))?;
    }
    let pixmap = render(tree, size)?;
    pixmap
        .save_png(path)
        .map_err(|e| format!("写 {}: {e}", path.display()))?;
    Ok(())
}
