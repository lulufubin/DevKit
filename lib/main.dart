import 'package:flutter/material.dart';
import 'package:devkit/src/rust/api/crypto.dart';
import 'package:devkit/src/rust/frb_generated.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  runApp(const DevKitApp());
}

class DevKitApp extends StatelessWidget {
  const DevKitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DevKit',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      home: const EncryptPage(),
    );
  }
}

class EncryptPage extends StatefulWidget {
  const EncryptPage({super.key});

  @override
  State<EncryptPage> createState() => _EncryptPageState();
}

class _EncryptPageState extends State<EncryptPage> {
  final _input = TextEditingController();
  final _output = TextEditingController();
  final _passphrase = TextEditingController();
  var _busy = false;
  var _obscure = true;
  String? _status;
  var _failed = false;

  @override
  void dispose() {
    _input.dispose();
    _output.dispose();
    _passphrase.dispose();
    super.dispose();
  }

  Future<void> _run({required bool encrypt}) async {
    final input = _input.text.trim();
    final output = _output.text.trim();
    final passphrase = _passphrase.text;
    if (input.isEmpty || output.isEmpty) {
      setState(() {
        _failed = true;
        _status = '请填写输入路径和输出路径';
      });
      return;
    }
    setState(() {
      _busy = true;
      _status = encrypt ? '正在加密…' : '正在解密…';
      _failed = false;
    });
    try {
      if (encrypt) {
        await encryptFile(input: input, output: output, passphrase: passphrase);
      } else {
        await decryptFile(input: input, output: output, passphrase: passphrase);
      }
      setState(() {
        _status = encrypt ? '加密完成：$output' : '解密完成：$output';
        _failed = false;
      });
    } catch (err) {
      setState(() {
        _status = '$err';
        _failed = true;
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DevKit')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '流式文件加密 / 解密',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  '使用 age 口令加密。按路径流式读写，不会把整个文件读进内存。',
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _input,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: '输入文件',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _output,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: '输出文件',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passphrase,
                  enabled: !_busy,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: '口令',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _obscure ? '显示口令' : '隐藏口令',
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    FilledButton(
                      onPressed: _busy ? null : () => _run(encrypt: true),
                      child: const Text('加密'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: _busy ? null : () => _run(encrypt: false),
                      child: const Text('解密'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (_busy) const LinearProgressIndicator(),
                if (_status != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _status!,
                    style: TextStyle(
                      color: _failed
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
