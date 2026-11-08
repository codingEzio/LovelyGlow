<p align="center">
  <img src="docs/icon.svg" width="120" height="120" alt="Lovely Glow">
</p>

# Lovely Glow

[English](README.md) · [简体中文](README.zh-Hans.md) · [繁體中文](README.zh-Hant.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md)

オプションの Pixel 書体には DeparturePixelZh Compact 0.1.1 を使用します。フォントは含まれていません。パッケージ前に `python3 script/get_compact_font.py` で固定版を取得・検証してください。詳細は [依存関係](DEPENDENCIES.md) を参照してください。 ローカルフォントを使う場合は、ビルド時に `LOVELYGLOW_PRIVATE_FONT` にファイルパスを指定します。ファイルはリポジトリ外か Git 管理外の `Local/` に置き、パッケージ化前に検証します。そのフォントに必要な権利表示を用意してください。

現在のアクティブウインドウに一本の光の縁を描く macOS ネイティブのメニューバーアプリです。内容を暗くせず、ウインドウの整列や他のアプリへの取り付けもしません。

## 動作

Glow を有効にすると前面アプリの現在のウインドウを追跡します。小さな無題の補助ウインドウは通常除外し、More で明示的に含められます。自分のメニュー、Cmd+Tab、Spotlight では元の対象を保持します。全画面、Mission Control、作業領域を埋めるウインドウでは隠れます。クリックを通過させ、キーボードフォーカスを奪いません。

メニューバーのポップオーバーで色、サイズ、動き、出現方法、フォントを調整します。既定は System、同梱 Pixel Compact は任意で保存できます。Instant と Seamless は同じオーバーレイを使い、現在のディスプレイの更新に従います。コアテストは実際のジェスチャー、滑らかさ、画素の一致を証明しません。Stage Manager、独自形状のウインドウ、将来の macOS の Space 検出には制限があります。

## ソースビルド

Apple Silicon、macOS 27 以降、選択済みの互換 Xcode／Swift 6.2 以降の SDK が必要です。ダウンロードする Swift パッケージや隣のリポジトリは不要です。まず Apple の通常の方法で Xcode を導入し、ライセンスを確認します。

```sh
swift build --jobs 2 --scratch-path Local/swift-build --product LovelyGlow
just test
python3 -m unittest discover -s script -p test_migrate_settings.py
```

`just` は既存コマンドのショートカットです。コアテストの同等コマンドは `swift test --jobs 2 --scratch-path Local/swift-test` です。合成データを使い、アプリ起動、アクセシビリティ要求、インストール、ログイン項目の変更は行いません。`SWIFT_JOBS` の既定値は 2、`SWIFT_SCRATCH_PATH` は `Local/swift-test` です。不正なオプションは失敗します。

### 開発版の実行

`./script/dev.sh --run` は個人用証明書なしでアドホック署名したアプリをビルドし、ターミナルで実行します。Control-C またはアプリの終了操作で停止します。`./script/dev.sh --build` はビルドのみです。各ビルドは別の `Local/lovelyglow-dev.*` に出力し、`Local/swift-dev-build` のキャッシュを再利用します。停止後、不要な出力を手動で削除できます。キャッシュはビルド中でないときに削除できます。失敗時の出力も残ります。

開発版の設定は `~/Library/Application Support/com.github.codingEzio.LovelyGlow.Development/config.toml` に保存され、製品版とは別です。設定を破棄するときだけそのディレクトリを削除してください。ログイン起動を有効にした場合は、アプリを削除する前に開発版で無効にしてください。macOS に権限記録が残る場合があります。任意のフォントがなくてもシステムフォントを使えます。

## 署名とインストール

`config/product.conf` があれば優先し、なければ同じ製品識別子と空の署名情報を持つ `config/product.public.conf` を使います。配布候補は個人用設定を含みません。コンパイル済み実行ファイルだけでは署名済みアプリの証拠になりません。

```sh
just stage
just install
```

これらは所有者が設定した証明書と署名識別子を必要とします。Stage は利用中のアプリを止めずに別候補を作ります。Install は既存アプリと署名要件が一致する場合のみ `~/Applications/LovelyGlow.app` を置き換えて起動します。アドホック署名や新しい bundle ID で回避しません。パッケージには iconutil／sips、任意の rsvg-convert、Python のアイコン代替経路を使います。

アクセシビリティは権限ボタンを操作して要求します。起動時には要求しません。未許可でも通常の切り替えはウインドウシステムの境界を使えますが、ドラッグ追跡は弱くなります。ログイン起動は利用者が有効にした SMAppService のみです。HTTP サービス、LaunchAgent、Process Compose はありません。

## データと移行

0.7.9／33 から唯一の設定先は `~/Library/Application Support/com.alex.LovelyGlow/config.toml` です。実行時設定をソースに書き戻しません。インストーラーは古い署名済みアプリのメタデータから従来の場所を読み、古いプロセス停止後にバイト単位でコピーして読み戻します。移行先に異なる内容があれば、どちらも上書きせず停止します。旧ファイルは復旧用に残します。新規導入は直接 Application Support を使います。ビルド出力は Git 対象外の Local／dist です。

## ライセンスとソース確認

README のマークは codingEzio による独立した文書用 SVG で、[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) です。製品アイコン、フォント、第三者の権利は変更しません。

独自ソフトウェアは [MIT](LICENSE)、フォントは[元の OFL と構成要素の通知](Resources/Licenses/NOTICE.md)を維持します。[LICENSE-SCOPE.md](LICENSE-SCOPE.md) が区分を定めます。このリポジトリは権利未確認の元アイコンを除き、明示された独自 CC BY 4.0 幾何プレースホルダーを使います。個人用パッケージの元アイコンを公開してよいという意味ではありません。

ソース履歴と検証範囲は [PUBLICATION.md](PUBLICATION.md) を参照してください。
