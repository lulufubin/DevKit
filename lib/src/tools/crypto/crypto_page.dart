import 'package:devkit/src/rust/api/crypto_tools.dart';
import 'package:devkit/src/widgets/tool_scaffold.dart';
import 'package:flutter/material.dart';

class CryptoPage extends StatefulWidget {
  const CryptoPage({super.key});

  @override
  State<CryptoPage> createState() => _CryptoPageState();
}

class _CryptoPageState extends State<CryptoPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 6, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      child: Column(
        children: [
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabs: const [
              Tab(text: '编解码'),
              Tab(text: '哈希'),
              Tab(text: 'AES'),
              Tab(text: 'HMAC'),
              Tab(text: 'RSA'),
              Tab(text: '国密'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [_CodecTab(), _HashTab(), _AesTab(), _HmacTab(), _RsaTab(), _SmTab()],
            ),
          ),
        ],
      ),
    );
  }
}

class _CodecTab extends StatefulWidget {
  const _CodecTab();
  @override
  State<_CodecTab> createState() => _CodecTabState();
}

class _CodecTabState extends State<_CodecTab> with ToolFeedback {
  final input = TextEditingController();
  final output = TextEditingController();
  var encoding = BinaryEncoding.base64;
  var urlMode = false;

  @override
  void dispose() {
    input.dispose();
    output.dispose();
    super.dispose();
  }

  Future<void> _run({required bool encode}) async {
    try {
      if (urlMode) {
        output.text = encode ? await urlEncode(input: input.text) : await urlDecode(input: input.text);
      } else if (encode) {
        output.text = await codecEncode(input: input.text, encoding: encoding);
      } else {
        output.text = await codecDecode(input: input.text, encoding: encoding);
      }
    } catch (error) {
      reportError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Form(children: [
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('URL 编解码'), value: urlMode, onChanged: (v) => setState(() => urlMode = v)),
      if (!urlMode)
        _Drop<BinaryEncoding>(label: '编码', value: encoding, values: const [BinaryEncoding.base64, BinaryEncoding.hex], labelOf: _enc, onChanged: (v) => setState(() => encoding = v)),
      _Area(label: '输入', controller: input),
      _Area(label: '输出', controller: output),
      Wrap(spacing: 8, children: [
        FilledButton(onPressed: () => _run(encode: true), child: const Text('编码')),
        OutlinedButton(onPressed: () => _run(encode: false), child: const Text('解码')),
        TextButton(onPressed: () => copyText(context, output.text), child: const Text('复制输出')),
      ]),
    ]);
  }
}

class _HashTab extends StatefulWidget {
  const _HashTab();
  @override
  State<_HashTab> createState() => _HashTabState();
}

class _HashTabState extends State<_HashTab> with ToolFeedback {
  final input = TextEditingController();
  final output = TextEditingController();
  var alg = HashAlg.sha256;
  var encoding = BinaryEncoding.utf8;

  @override
  void dispose() {
    input.dispose();
    output.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Form(children: [
      _Drop(label: '算法', value: alg, values: HashAlg.values, labelOf: _hash, onChanged: (v) => setState(() => alg = v)),
      _Drop(label: '输入编码', value: encoding, values: BinaryEncoding.values, labelOf: _enc, onChanged: (v) => setState(() => encoding = v)),
      _Area(label: '输入', controller: input),
      _Area(label: '哈希（Hex）', controller: output),
      FilledButton(
        onPressed: () async {
          try {
            output.text = await hashText(input: input.text, encoding: encoding, alg: alg);
          } catch (error) {
            reportError(error);
          }
        },
        child: const Text('计算'),
      ),
    ]);
  }
}

class _AesTab extends StatefulWidget {
  const _AesTab();
  @override
  State<_AesTab> createState() => _AesTabState();
}

class _AesTabState extends State<_AesTab> with ToolFeedback {
  final input = TextEditingController();
  final key = TextEditingController();
  final output = TextEditingController();
  var inputEnc = BinaryEncoding.utf8;
  var keyEnc = BinaryEncoding.utf8;
  var outputEnc = BinaryEncoding.base64;

  @override
  void dispose() {
    input.dispose();
    key.dispose();
    output.dispose();
    super.dispose();
  }

  Future<void> _run({required bool encrypt}) async {
    try {
      output.text = encrypt
          ? await aes256GcmEncrypt(key: key.text, keyEncoding: keyEnc, plaintext: input.text, plaintextEncoding: inputEnc, outputEncoding: outputEnc)
          : await aes256GcmDecrypt(key: key.text, keyEncoding: keyEnc, ciphertext: input.text, ciphertextEncoding: inputEnc, outputEncoding: outputEnc);
    } catch (error) {
      reportError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Form(children: [
      const Text('AES-256-GCM。密钥须 32 字节；密文前 12 字节为随机 nonce。'),
      _Area(label: '明文 / 密文', controller: input, minLines: 4),
      TextField(controller: key, decoration: const InputDecoration(labelText: '密钥', border: OutlineInputBorder())),
      _Drop(label: '输入编码', value: inputEnc, values: BinaryEncoding.values, labelOf: _enc, onChanged: (v) => setState(() => inputEnc = v)),
      _Drop(label: '密钥编码', value: keyEnc, values: BinaryEncoding.values, labelOf: _enc, onChanged: (v) => setState(() => keyEnc = v)),
      _Drop(label: '输出编码', value: outputEnc, values: const [BinaryEncoding.hex, BinaryEncoding.base64, BinaryEncoding.utf8], labelOf: _enc, onChanged: (v) => setState(() => outputEnc = v)),
      _Area(label: '输出', controller: output, minLines: 4),
      Wrap(spacing: 8, children: [
        FilledButton(onPressed: () => _run(encrypt: true), child: const Text('加密')),
        OutlinedButton(onPressed: () => _run(encrypt: false), child: const Text('解密')),
      ]),
    ]);
  }
}

class _HmacTab extends StatefulWidget {
  const _HmacTab();
  @override
  State<_HmacTab> createState() => _HmacTabState();
}

class _HmacTabState extends State<_HmacTab> with ToolFeedback {
  final key = TextEditingController();
  final message = TextEditingController();
  final output = TextEditingController();

  @override
  void dispose() {
    key.dispose();
    message.dispose();
    output.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Form(children: [
      TextField(controller: key, decoration: const InputDecoration(labelText: '密钥', border: OutlineInputBorder())),
      _Area(label: '消息', controller: message, minLines: 4),
      _Area(label: 'HMAC-SHA256（Hex）', controller: output, minLines: 3),
      FilledButton(
        onPressed: () async {
          try {
            output.text = await hmacSha256(key: key.text, keyEncoding: BinaryEncoding.utf8, message: message.text, messageEncoding: BinaryEncoding.utf8);
          } catch (error) {
            reportError(error);
          }
        },
        child: const Text('计算'),
      ),
    ]);
  }
}

class _RsaTab extends StatefulWidget {
  const _RsaTab();
  @override
  State<_RsaTab> createState() => _RsaTabState();
}

class _RsaTabState extends State<_RsaTab> with ToolFeedback {
  final publicPem = TextEditingController();
  final privatePem = TextEditingController();
  final input = TextEditingController();
  final output = TextEditingController();
  var padding = RsaPadding.oaepSha256;
  var signPadding = RsaSignPadding.pssSha256;

  @override
  void dispose() {
    publicPem.dispose();
    privatePem.dispose();
    input.dispose();
    output.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Form(children: [
      _Area(label: '公钥 PEM', controller: publicPem, minLines: 3),
      _Area(label: '私钥 PEM（仅会话内）', controller: privatePem, minLines: 3),
      FilledButton.tonal(
        onPressed: () async {
          try {
            final pair = await rsaGenerateKeypair(bits: 2048);
            publicPem.text = pair.publicPem;
            privatePem.text = pair.privatePem;
          } catch (error) {
            reportError(error);
          }
        },
        child: const Text('生成 2048 位密钥对'),
      ),
      _Drop(label: '加密填充', value: padding, values: RsaPadding.values, labelOf: _rsaPad, onChanged: (v) => setState(() => padding = v)),
      _Drop(label: '签名填充', value: signPadding, values: RsaSignPadding.values, labelOf: _rsaSign, onChanged: (v) => setState(() => signPadding = v)),
      _Area(label: '明文 / 密文 / 待签消息', controller: input, minLines: 3),
      _Area(label: '输出', controller: output, minLines: 3),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton(
          onPressed: () async {
            try {
              output.text = await rsaEncrypt(publicPem: publicPem.text, plaintext: input.text, plaintextEncoding: BinaryEncoding.utf8, padding: padding, outputEncoding: BinaryEncoding.base64);
            } catch (error) {
              reportError(error);
            }
          },
          child: const Text('加密'),
        ),
        OutlinedButton(
          onPressed: () async {
            try {
              output.text = await rsaDecrypt(privatePem: privatePem.text, ciphertext: input.text, ciphertextEncoding: BinaryEncoding.base64, padding: padding, outputEncoding: BinaryEncoding.utf8);
            } catch (error) {
              reportError(error);
            }
          },
          child: const Text('解密'),
        ),
        FilledButton.tonal(
          onPressed: () async {
            try {
              output.text = await rsaSign(privatePem: privatePem.text, message: input.text, messageEncoding: BinaryEncoding.utf8, padding: signPadding, outputEncoding: BinaryEncoding.base64);
            } catch (error) {
              reportError(error);
            }
          },
          child: const Text('签名'),
        ),
        OutlinedButton(
          onPressed: () async {
            try {
              final ok = await rsaVerify(publicPem: publicPem.text, message: input.text, messageEncoding: BinaryEncoding.utf8, signature: output.text, signatureEncoding: BinaryEncoding.base64, padding: signPadding);
              reportMessage(ok ? '验签通过' : '验签失败');
            } catch (error) {
              reportError(error);
            }
          },
          child: const Text('验签'),
        ),
      ]),
    ]);
  }
}

class _SmTab extends StatefulWidget {
  const _SmTab();
  @override
  State<_SmTab> createState() => _SmTabState();
}

class _SmTabState extends State<_SmTab> with ToolFeedback {
  final input = TextEditingController();
  final key = TextEditingController();
  final publicHex = TextEditingController();
  final privateHex = TextEditingController();
  final output = TextEditingController();
  var mode = Sm4Mode.cbc;

  @override
  void dispose() {
    input.dispose();
    key.dispose();
    publicHex.dispose();
    privateHex.dispose();
    output.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() body) async {
    try {
      await body();
    } catch (error) {
      reportError(error);
    }
  }

  Future<void> _sm3() => _run(() async {
    output.text = await sm3Hash(input: input.text, encoding: BinaryEncoding.utf8);
  });

  Future<void> _sm4Encrypt() => _run(() async {
    output.text = await sm4Encrypt(
      key: key.text,
      keyEncoding: BinaryEncoding.hex,
      plaintext: input.text,
      plaintextEncoding: BinaryEncoding.utf8,
      mode: mode,
      outputEncoding: BinaryEncoding.hex,
    );
  });

  Future<void> _sm4Decrypt() => _run(() async {
    output.text = await sm4Decrypt(
      key: key.text,
      keyEncoding: BinaryEncoding.hex,
      ciphertext: input.text,
      ciphertextEncoding: BinaryEncoding.hex,
      mode: mode,
      outputEncoding: BinaryEncoding.utf8,
    );
  });

  Future<void> _sm2Generate() => _run(() async {
    final pair = await sm2GenerateKeypair();
    privateHex.text = pair.privateHex;
    publicHex.text = pair.publicHex;
  });

  Future<void> _sm2Encrypt() => _run(() async {
    output.text = await sm2Encrypt(
      publicHex: publicHex.text,
      plaintext: input.text,
      plaintextEncoding: BinaryEncoding.utf8,
      outputEncoding: BinaryEncoding.hex,
    );
  });

  Future<void> _sm2Decrypt() => _run(() async {
    output.text = await sm2Decrypt(
      privateHex: privateHex.text,
      ciphertext: input.text,
      ciphertextEncoding: BinaryEncoding.hex,
      outputEncoding: BinaryEncoding.utf8,
    );
  });

  Future<void> _sm2Sign() => _run(() async {
    output.text = await sm2Sign(
      privateHex: privateHex.text,
      message: input.text,
      messageEncoding: BinaryEncoding.utf8,
      outputEncoding: BinaryEncoding.hex,
    );
  });

  Future<void> _sm2Verify() => _run(() async {
    final ok = await sm2Verify(
      publicHex: publicHex.text,
      message: input.text,
      messageEncoding: BinaryEncoding.utf8,
      signature: output.text,
      signatureEncoding: BinaryEncoding.hex,
    );
    reportMessage(ok ? '验签通过' : '验签失败');
  });

  @override
  Widget build(BuildContext context) {
    return _Form(children: [
      _Area(label: '输入', controller: input, minLines: 3),
      TextField(controller: key, decoration: const InputDecoration(labelText: 'SM4 密钥 Hex（16 字节）', border: OutlineInputBorder())),
      _Drop(label: 'SM4 模式', value: mode, values: Sm4Mode.values, labelOf: (v) => v == Sm4Mode.cbc ? 'CBC（IV 自动前置）' : 'ECB', onChanged: (v) => setState(() => mode = v)),
      _Area(label: 'SM2 公钥 Hex', controller: publicHex, minLines: 2),
      _Area(label: 'SM2 私钥 Hex（仅会话内）', controller: privateHex, minLines: 2),
      _Area(label: '输出', controller: output, minLines: 3),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton(onPressed: _sm3, child: const Text('SM3')),
        FilledButton.tonal(onPressed: _sm4Encrypt, child: const Text('SM4 加密')),
        OutlinedButton(onPressed: _sm4Decrypt, child: const Text('SM4 解密')),
        FilledButton.tonal(onPressed: _sm2Generate, child: const Text('生成 SM2')),
        FilledButton(onPressed: _sm2Encrypt, child: const Text('SM2 加密')),
        OutlinedButton(onPressed: _sm2Decrypt, child: const Text('SM2 解密')),
        FilledButton.tonal(onPressed: _sm2Sign, child: const Text('SM2 签名')),
        OutlinedButton(onPressed: _sm2Verify, child: const Text('SM2 验签')),
      ]),
    ]);
  }
}

class _Form extends StatelessWidget {
  const _Form({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.only(top: 8, right: 8), children: [for (final c in children) ...[c, const SizedBox(height: 12)]]);
  }
}

class _Area extends StatelessWidget {
  const _Area({required this.label, required this.controller, this.minLines = 5});
  final String label;
  final TextEditingController controller;
  final int minLines;
  @override
  Widget build(BuildContext context) {
    return TextField(controller: controller, minLines: minLines, maxLines: minLines + 6, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()));
  }
}

class _Drop<T> extends StatelessWidget {
  const _Drop({required this.label, required this.value, required this.values, required this.labelOf, required this.onChanged});
  final String label;
  final T value;
  final List<T> values;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          items: [for (final item in values) DropdownMenuItem(value: item, child: Text(labelOf(item)))],
          onChanged: (next) { if (next != null) onChanged(next); },
        ),
      ),
    );
  }
}

String _enc(BinaryEncoding e) => switch (e) { BinaryEncoding.utf8 => 'UTF-8', BinaryEncoding.hex => 'Hex', BinaryEncoding.base64 => 'Base64' };
String _hash(HashAlg a) => switch (a) { HashAlg.md5 => 'MD5', HashAlg.sha1 => 'SHA-1', HashAlg.sha256 => 'SHA-256', HashAlg.sm3 => 'SM3' };
String _rsaPad(RsaPadding p) => switch (p) { RsaPadding.oaepSha256 => 'OAEP-SHA256', RsaPadding.pkcs1V15 => 'PKCS#1 v1.5' };
String _rsaSign(RsaSignPadding p) => switch (p) { RsaSignPadding.pkcs1V15Sha256 => 'PKCS#1 v1.5 + SHA-256', RsaSignPadding.pssSha256 => 'PSS + SHA-256' };
