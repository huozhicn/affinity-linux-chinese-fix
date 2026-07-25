# Affinity Linux 한국어 UI 수정

**语言 / 語言 / 언어 / 言語**: [简体中文](README.md) | [繁體中文](README.zh-TW.md) | [한국어](README.ko.md) | [日本語](README.ja.md)

[AffinityLinux](https://github.com/ryzendew/Linux-Affinity-Installer) AppImage 버전에서 UI 언어를 한국어로 변경하면 모든 한글이 네모("□□")로 표시되는 문제를 수정합니다.

> 이 저장소는 **문서와 스크립트만** 포함하며, 폰트 파일이나 Affinity 프로그램 파일은 포함하지 않습니다([법적 고지](#법적-고지) 참고).

## 문제 현상

AppImage는 정상적으로 실행되지만, 설정 → 일반 → 언어를 한국어로 바꾸면 UI의 한글이 전부 네모로 표시됩니다.

## 수정 결과

![수정 후 UI](docs/screenshot-fixed.jpg)

메뉴, 패널, 캔버스 텍스트가 모두 정상 표시됩니다(중국어 UI 예시 — 한국어 UI도 동일한 원리로 수정됩니다).

## 원인 분석 (세 가지 복합 문제)

1. **GDI 폰트 치환은 무효**: Affinity v3의 UI는 WPF(DirectWrite)로 렌더링되므로, Wine 레지스트리의 `FontSubstitutes` / `FontLink`(GDI 계층)가 전혀 적용되지 않습니다. 흔한 "Wine 한글 깨짐 레지스트리 수정" 방법은 여기서 효과가 없습니다.

2. **WPF 폰트 대체(fallback)는 실제 Windows 폰트가 필요**: WPF는 `C:\Windows\Fonts\GlobalUserInterface.CompositeFont`를 통해 언어/문자 범위별 폰트 대체를 수행합니다. 한국어(ko)의 한글은 `Malgun Gothic`(맑은 고딕) → `Gulim`(굴림)으로 대처리됩니다. AppImage의 Wine prefix에는 이 폰트들이 없어서 전부 `.notdef`(네모)로 렌더링됩니다.
   - 주의: **오픈소스 폰트를 Windows 폰트 이름으로 개조하는 방법은 불가능합니다**. Noto Sans CJK를 `Malgun Gothic` 등으로 개명하면 Wine은 로드하지만 Affinity가 `Serif.Affinity.Application.PostLoad()`에서 `NullReferenceException`으로 크래시됩니다(CFF, TrueType, TTC 모든 형태에서 동일). 반드시 실제 Windows 폰트 파일을 사용해야 합니다.

3. **레지스트리 함정**: 이 AppImage의 `system.reg` 파일 **맨 위**에는 무효 구간이 있습니다:
   ```
   [HKEY_LOCAL_MACHINESoftwareMicrosoftWindows NTCurrentVersionFonts]
   ```
   패키징 스크립트가 수동으로 추가한 것으로, **Wine은 이것을 폰트 등록 키로 인식하지 않습니다**. 실제 폰트 등록 키는:
   ```
   [Software\Microsoft\Windows NT\CurrentVersion\Fonts]
   ```
   잘못된 구간에 등록하면 아무 오류 없이 그냥 적용되지 않습니다.

## 빠른 시작

전제: **본인이 합법적으로 보유한** Windows 설치의 폰트(듀얼부팅 파티션 또는 다른 Windows PC의 `C:\Windows\Fonts`).

```bash
# 예 1: 마운트된 Windows 파티션을 직접 지정
./fix-affinity-chinese.sh /media/usb/Windows/Fonts

# 예 2: 필요한 폰트를 디렉터리에 복사한 뒤 지정
./fix-affinity-chinese.sh ~/my-win-fonts
```

스크립트가 자동으로 하는 일:

1. 소스 디렉터리에서 필요한 폰트를 가져옵니다(존재하는 것만, 핵심 요구 사항은 `msyh.ttc`);
2. prefix의 `drive_c/winefonts/`로 복사;
3. `system.reg` 백업(`system.reg.bak-타임스탬프`);
4. **올바른** Fonts 키에 등록 항목 기록(멱등, 반복 실행 가능).

이후 Affinity를 실행하면 됩니다.

**한국어 사용자 추가 안내**: 스크립트의 기본 폰트 목록은 중국어용입니다. 한국어 UI에는 맑은 고딕이 필요하므로, Windows에서 다음 파일을 prefix의 `drive_c/winefonts/`에 함께 복사하고 `system.reg`의 동일한 등록 키에 아래 항목을 추가하세요:

| 파일 | 등록 항목 |
|---|---|
| `malgun.ttf` | `"Malgun Gothic (TrueType)"` |
| `malgunbd.ttf` | `"Malgun Gothic Bold (TrueType)"` |
| `malgunsl.ttf` | `"Malgun Gothic Semilight (TrueType)"` |
| `gulim.ttc` | `"Gulim & GulimChe & Dotum & DotumChe (TrueType)"` |

prefix가 기본 위치(`~/.AffinityLinux-Appimage`)가 아닌 경우:

```bash
AFFINITY_PREFIX=/your/prefix ./fix-affinity-chinese.sh /media/usb/Windows/Fonts
```

## LLM 에이전트용

사용 중인 LLM 에이전트(Kimi Code, Claude Code, Cursor 등)에게 수정을 맡기고 싶다면 [FOR_LLM_AGENT.md](FOR_LLM_AGENT.md)의 내용을 그대로 복사해서 붙여넣으세요. 확정된 원인, 금지 사항, 검증 절차가 모두 적혀 있어 에이전트가 재조사 없이 바로 작업할 수 있습니다.

## 주의 사항

- prefix가 재생성/초기화되면 스크립트를 다시 실행하세요.
- 이 AppImage에는 메모리 사용량이 높은 알려진 문제(업스트림 issue #106)가 있으며, 본 수정과는 무관합니다.
- 폰트 문제 진단 시 `WINEDEBUG=+font,+dwrite`로 실행해 로그를 확인할 수 있습니다(과도한 트레이싱은 프로세스를 불안정하게 만들 수 있으므로 진단용으로만 사용).

## 법적 고지

- 이 저장소는 **문서와 스크립트만** 포함하며, 어떤 폰트 파일이나 Affinity 프로그램 파일도 포함/제공하지 않습니다.
- `malgun.ttf`(맑은 고딕), `msyh.ttc`(微软雅黑) 등 폰트의 저작권은 Microsoft 등 원제작사에 있으며, **공개 재배포가 허용되지 않습니다**. 본인의 합법적인 Windows 설치에서 가져온 폰트를 개인 용도로만 사용하세요.
- 마찬가지로 Affinity 프로그램 본처이나 위 폰트를 포함한 AppImage를 재패키징하여 배포하면 Serif 및 폰트 제작사의 저작권을 침해합니다.

## 참고

- [ryzendew/Linux-Affinity-Installer](https://github.com/ryzendew/Linux-Affinity-Installer) 및 [Known issues](https://github.com/ryzendew/Linux-Affinity-Installer/blob/main/docs/Known-issues.md)

## License

스크립트와 문서는 [MIT](LICENSE)으로 배포됩니다(제3자 폰트/프로그램 파일 무관).
