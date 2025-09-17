# Onboarding Goal Screen – Design System (v1)

> このドキュメントは、提示いただいた「What’s your goal?」画面を核に、他画面へ横展開できる**汎用的なデザイン定義**です。  
> 英語文言は “Skill **Improvement**” を推奨（元画面は “Improvment” になっているため要修正）。

---

## 1) デザイン原則（3つ）
- **読みやすさ優先**：余白はタイポより強い。4pt ベースの 8pt スケールで一貫管理。
- **軽い遊び × 実務的**：やわらかい背景シェイプやグラデと、明快な階層（見出し・カード・CTA）を両立。
- **状態の明示**：押下・選択・無効を必ず色/影/境界で可視化。アクセシビリティ AA 準拠。

---

## 2) レイアウト・グリッド
- **ベースグリッド**：4pt。主要スペーシングは `4 / 8 / 12 / 16 / 20 / 24 / 32`。
- **左右マージン**：20pt（Safe Area 内）。ホームインジケータ上は**底部余白 24–32pt**を確保。
- **セクション構成（上→下）**
  1. **トップバー**（戻る・Skip）。高さ 56pt、タップ領域 44×44pt 以上。
  2. **ページタイトル**（大見出し）。下余白 16–20pt。
  3. **カードリスト**（縦積み）。カード間隔 12pt。
  4. **進捗インジケータ**（段階式バー or ドット）。下余白 12pt。
  5. **主要 CTA**（右下の丸ボタン）。他要素と**32pt**以上の距離。

---

## 3) タイポグラフィ
- **フォント**：iOS は *SF Pro*（日本語はシステム既定で可。サンセリフ系前提）。
- **スケール**（LH = line height）
  - `Display/L`: 32pt, Semibold, LH 38
  - `Title/M`: 24pt, Semibold, LH 30
  - `Body/M`: 16pt, Regular, LH 22（本文・カードラベル）
  - `Caption`: 13pt, Regular, LH 18
- **文字色**：`text/primary`、`text/secondary`、`text/inverse` の 3 段。
- **多言語伸び対策**：タイトルは 2 行まで。カードラベルは 1 行、省略可。

---

## 4) カラートークン（スロット設計＋サンプル）
> 実装は「スロット名」で参照。HEX はサンプル（置き換え可）。小サイズ文字のコントラストは **AA 4.5:1** 以上。

```json
{
  "color": {
    "brand": {
      "primary": "#2B6BE4",
      "primary/hover": "#255CC5",
      "primary/pressed": "#1F4EA5"
    },
    "bg": {
      "base": "#F2EBDD",
      "surface": "#FFFFFF",
      "tint": "#F8F5EE"
    },
    "text": {
      "primary": "#15171A",
      "secondary": "#5E6672",
      "inverse": "#FFFFFF",
      "link": "#2B6BE4"
    },
    "border": {
      "subtle": "#E6E2D8",
      "strong": "#C9C2B3",
      "focus": "#2B6BE4"
    },
    "state": {
      "success": "#3CB371",
      "warning": "#E8A13A",
      "danger": "#E25555"
    },
    "goalGradients": {
      "teal": ["#5AC2B9", "#3E9E95"],
      "indigo": ["#6C6BD7", "#4C49B8"],
      "amber": ["#F4C76A", "#E6A94C"],
      "salmon": ["#F19A86", "#E3766A"]
    }
  }
}
```

---

## 5) コーナー・影・ブラー
- **角丸**：`xl=20`（カード/CTA 丸）、`l=16`（カード既定）、`m=12`（バッジ）、`full`（丸ボタン）。
- **影（iOS）**
  - `elev/1`（カード既定）：y=2, blur=8, rgba(0,0,0,0.08)
  - `elev/2`（押下）：y=1, blur=4, rgba(0,0,0,0.12)
- **背景シェイプ**：装飾レイヤーは**不透明度 8–12%**目安。テキストと競合させない。

---

## 6) コンポーネント仕様

### A. トップバー
- **構成**：左「Back（chevron）」、右「Skip（テキストリンク）」
- **高さ**：56pt、**タップ領域 44pt** 以上
- **Skip**：`Body/M`＋`text/link`、押下時 `underline` or `alpha 0.72`

### B. ページタイトル
- **スタイル**：`Display/L`、`text/primary`
- **余白**：上 12–16pt（バーとの間）、下 16–20pt
- **説明文（任意）**：`Body/M` `text/secondary`、上余白 8pt

### C. オプションカード（例：「Start yoga」など）
- **サイズ**：最小高さ 64–72pt、横幅は親幅いっぱい、**内部パディング 16pt**
- **角丸**：16pt、影 `elev/1`
- **背景**：`goalGradients.*` の線形グラデ（左→右 45°）
- **装飾シルエット**：右側 24–32pt アイコン/シェイプ、**不透明度 12–18%**
- **テキスト**：左寄せ、`Body/M` + Medium/Semibold、`text/inverse`
- **間隔**：カード間 12pt
- **状態**
  - **Pressed**：スケール 0.98、オーバーレイ `#000` 8% もしくは輝度 -5%、影を `elev/2`
  - **Selected**：外枠 2pt `brand/primary`、または左端 4pt の選択インジケータ。右上チェック 20pt 併用可
  - **Disabled**：彩度 -30%、明度 +10%、テキスト `#FFFFFF`→`#FFFFFFCC`
- **可変内容**：2 行まで許容（`line-clamp:2`）。アイコン非表示でも崩れない

### D. 主要 CTA（右下の丸矢印）
- **サイズ**：56×56pt、`brand/primary` 塗り、アイコン 24pt `text/inverse`
- **位置**：右下、Safe Area 内から **右/下 20–24pt**
- **状態**：Pressed=スケール 0.96、影強度 +20%；Disabled=30% 不透明
- **ロングプレス**：触覚（軽）
- **代替**：フォーム画面では**フル幅ボタン**（高さ 52–56pt、角丸 14–16pt）に置換可

### E. 進捗インジケータ（ステップ）
- **バー**：高さ 4pt、角丸 2pt、`track=#E6E2D8`、アクティブ `brand/primary`
- **ドット**：直径 6pt、間隔 6pt、アクティブは直径 8pt
- **配置**：CTA 左上付近（下余白 12pt）

### F. テキストリンク
- **既定**：`text/link` 色、押下時 alpha 0.72
- **フォーカス**：`border/focus` で 2pt アウトライン（アクセシビリティ）

---

## 7) インタラクション & モーション
- **押下アニメ**：100–150ms（Cubic Bezier: 0.2, 0.8, 0.2, 1）
- **画面遷移**：横スライド 240ms（Onboarding 流儀）
- **カード選択**：色の揺らぎ + チェック/ボーダーで 120ms

---

## 8) アクセシビリティ
- タップ領域 **44×44pt** 以上
- コントラスト：本文 4.5:1、見出し 3:1 以上
- VoiceOver：カードは「選択肢、ラベル、選択状態、ヒント（ダブルタップで選択）」を付与
- 動的タイプ：`Body/M` 以上はサイズアップで**2 行崩れ**を許容
- カラー依存禁止：選択は**色＋形（枠/チェック）**の併用

---

## 9) イラスト/アイコン指針
- **アイコン**：線の太さ 2pt、角丸端。単色で `text/inverse` または `text/secondary`
- **シルエット**：カード右側の装飾は**コントラスト 3:1 未満**に抑える
- **アセット形式**：SVG 推奨（解像度非依存）。@1x/2x/3x は自動書き出し

---

## 10) デザイントークン（実装向け・最小）
> Figma Variables / JSON / SwiftUI / Flutter で流用可能。

```json
{
  "radius": { "m": 12, "l": 16, "xl": 20, "full": 999 },
  "space": { "xs": 4, "s": 8, "m": 12, "md": 16, "lg": 20, "xl": 24, "xxl": 32 },
  "elev": {
    "1": { "y": 2, "blur": 8, "color": "rgba(0,0,0,0.08)" },
    "2": { "y": 1, "blur": 4, "color": "rgba(0,0,0,0.12)" }
  },
  "typography": {
    "displayL": { "size": 32, "lh": 38, "weight": 600 },
    "titleM": { "size": 24, "lh": 30, "weight": 600 },
    "bodyM": { "size": 16, "lh": 22, "weight": 400 },
    "caption": { "size": 13, "lh": 18, "weight": 400 }
  },
  "component": {
    "cardHeightMin": 68,
    "cardPadding": 16,
    "ctaFabSize": 56,
    "progressHeight": 4
  }
}
```

---

## 11) 自動レイアウト & ルール（実装/デザイン両方）
- **カードリスト**：親は縦スタック、`spacing=12`、子カードは**横方向 Fill**、`minHeight=68`、内部は「左テキスト（伸縮）・右装飾（固定 24–32）」の 2 カラム。
- **CTA**：右下アンカー（Safe Area）。他要素と**重ならない**よう、カード最下段の下にスペーサー 16–24。
- **進捗**：ステップ数は可変。バーは Flex、ドットは Wrap を禁止（1 行固定）。

---

## 12) 画面テンプレ（同系オンボーディングに流用）
- **Variant A**：質問タイトル＋**単一選択**カード（今画面）。必須選択なら、Next 有効化は**選択時のみ**。
- **Variant B**：**複数選択**（チェック）。CTA は「Continue (n)」。
- **Variant C**：長文説明＋画像（装飾を左、CTA を下部フル幅）。
- **Variant D**：入力フォーム（フィールド群、バリデーションはリアルタイム、CTA フル幅）。

---

## 13) 品質チェックリスト
- [ ] タイトル 2 行時に CTA や進捗と衝突しない
- [ ] カード文言が長い言語（DE/JA）でも破綻しない
- [ ] ダークモード（背景/影/グラデの再設計）
- [ ] コントラスト AA クリア
- [ ] VoiceOver の順序：Back → Title → Options(top→bottom) → Progress → CTA → Skip
- [ ] iPhone mini/Pro Max・縦横で確認

---

## 14) 実装スニペット（SwiftUI 例）
```swift
import SwiftUI

struct GoalCard: View {
  let title: String
  let gradient: [Color]
  let selected: Bool

  var body: some View {
    HStack {
      Text(title)
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(.white)
        .lineLimit(2)
        .multilineTextAlignment(.leading)
      Spacer(minLength: 16)
      // 装飾シルエット（opacity 0.15 目安）
      Image(systemName: "figure.yoga") // 仮
        .resizable().scaledToFit().frame(width: 28, height: 28)
        .foregroundColor(.white.opacity(0.18))
    }
    .padding(16)
    .frame(minHeight: 68)
    .background(
      LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(selected ? Color("brand/primary") : .clear, lineWidth: 2)
    )
    .cornerRadius(16)
    .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
  }
}
```
