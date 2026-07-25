# Affinity Linux 日本語UI修正

**语言 / 語言 / 언어 / 言語**: [简体中文](README.md) | [繁體中文](README.zh-TW.md) | [한국어](README.ko.md) | [日本語](README.ja.md)

[AffinityLinux](https://github.com/ryzendew/Linux-Affinity-Installer) AppImage 版で UI 言語を日本語に切り替えると、すべての日本語が四角（「□□」、いわゆる豆腐）で表示される問題を修正します。

> このリポジトリには**ドキュメントとスクリプトのみ**が含まれ、フォントファイルや Affinity のプログラムファイルは一切含まれません（[法的通知](#法的通知)を参照）。

## 問題の症状

AppImage は正常に起動しますが、設定 → 一般 → 言語 を日本語に変更すると、UI の日本語がすべて四角になります。

## 修正結果

![修正後のUI](docs/screenshot-fixed.jpg)

メニュー、パネル、キャンバステキストがすべて正常に表示されます（中国語UIの例 — 日本語UIも同じ仕組みで修正できます）。

## 原因分析（3つの複合要因）

1. **GDI のフォント置換は無効**：Affinity v3 の UI は WPF（DirectWrite）で描画されているため、Wine レジストリの `FontSubstitutes` / `FontLink`（GDI 層）は一切効果がありません。よくある「Wine の文字化けをレジストリで直す」方法はここでは無効です。

2. **WPF のフォントフォールバックには実際の Windows フォントが必要**：WPF は `C:\Windows\Fonts\GlobalUserInterface.CompositeFont` を使い、言語・文字範囲ごとにフォントをフォールバックします。日本語（ja）の文字は `Meiryo`（メイリオ）→ `MS Gothic`（MS ゴシック）→ `Microsoft YaHei` にフォールバックされます。AppImage の Wine prefix にはこれらのフォントが存在しないため、すべて `.notdef`（四角）で描画されます。
   - 注意：**オープンソースフォントを Windows フォント名に改名する方法は使えません**。Noto Sans CJK を `Meiryo` などに改名すると Wine は読み込みますが、Affinity が `Serif.Affinity.Application.PostLoad()` で `NullReferenceException` を投げてクラッシュします（CFF、TrueType、TTC いずれの形式でも同様）。必ず本物の Windows フォントファイルを使用してください。

3. **レジストリの落とし穴**：この AppImage の `system.reg` の**先頭**には無効なセクションがあります：
   ```
   [HKEY_LOCAL_MACHINESoftwareMicrosoftWindows NTCurrentVersionFonts]
   ```
   パッケージングスクリプトが手動で追加したもので、**Wine はこれをフォント登録キーとして認識しません**。本物のフォント登録キーは：
   ```
   [Software\Microsoft\Windows NT\CurrentVersion\Fonts]
   ```
   誤ったセクションに登録しても、エラーなく単に反映されません。

## クイックスタート

前提：**ご自身が合法的に所有する** Windows インストールのフォント（デュアルブートのパーティション、別の Windows PC の `C:\Windows\Fonts` など）。

```bash
# 例 1: マウント済みの Windows パーティションを直接指定
./fix-affinity-chinese.sh /media/usb/Windows/Fonts

# 例 2: 必要なフォントをディレクトリにコピーしてから指定
./fix-affinity-chinese.sh ~/my-win-fonts
```

スクリプトが自動で行うこと：

1. ソースディレクトリから必要なフォントを取得（存在するもののみ、必須は `msyh.ttc`）;
2. prefix の `drive_c/winefonts/` にコピー;
3. `system.reg` をバックアップ（`system.reg.bak-タイムスタンプ`）;
4. **正しい** Fonts キーに登録エントリを書き込み（冪等、繰り返し実行可能）。

その後 Affinity を起動するだけです。

**日本語ユーザーへの追加案内**：スクリプトのデフォルトのフォントリストは中国語向けです。日本語 UI にはメイリオと MS ゴシックが必要なため、Windows から以下のファイルを prefix の `drive_c/winefonts/` に一緒にコピーし、`system.reg` の同じ登録キーに下記エントリを追加してください：

| ファイル | 登録エントリ |
|---|---|
| `meiryo.ttc` | `"Meiryo & Meiryo UI (TrueType)"` |
| `meiryob.ttc` | `"Meiryo Bold & Meiryo UI Bold (TrueType)"` |
| `msgothic.ttc` | `"MS Gothic & MS PGothic & MS UI Gothic (TrueType)"` |

prefix がデフォルトの場所（`~/.AffinityLinux-Appimage`）でない場合：

```bash
AFFINITY_PREFIX=/your/prefix ./fix-affinity-chinese.sh /media/usb/Windows/Fonts
```

## LLM エージェント向け

お使いの LLM エージェント（Kimi Code、Claude Code、Cursor など）に修正を任せたい場合は、[FOR_LLM_AGENT.md](FOR_LLM_AGENT.md) の内容をそのままコピー＆ペーストしてください。確定済みの原因、禁止事項、検証手順がすべて記載されているため、エージェントは再調査なしですぐに作業を開始できます。

## 注意事項

- prefix が再作成/リセットされた場合はスクリプトを再実行してください。
- この AppImage にはメモリ使用量が多い既知の問題（上流 issue #106）がありますが、本修正とは無関係です。
- フォント問題の診断には `WINEDEBUG=+font,+dwrite` で起動してログを確認できます（過度なトレーシングはプロセスを不安定にする可能性があるため、診断目的のみに使用）。

## 法的通知

- このリポジトリには**ドキュメントとスクリプトのみ**が含まれ、フォントファイルや Affinity のプログラムファイルは一切含まれず、提供もしません。
- `meiryo.ttc`（メイリオ）、`msgothic.ttc`（MS ゴシック）、`msyh.ttc`（微软雅黑）などのフォントの著作権は Microsoft などの権利者に帰属し、**公開再配布は許可されていません**。ご自身の合法的な Windows インストールから取得したフォントを、個人利用に限り使用してください。
- 同様に、Affinity 本体や上記フォントを含む AppImage を再パッケージして公開することは、Serif およびフォント権利者の著作権を侵害します。

## 参考

- [ryzendew/Linux-Affinity-Installer](https://github.com/ryzendew/Linux-Affinity-Installer) および [Known issues](https://github.com/ryzendew/Linux-Affinity-Installer/blob/main/docs/Known-issues.md)

## License

スクリプトとドキュメントは [MIT](LICENSE) で公開（サードパーティのフォント/プログラムファイルとは無関係）。
